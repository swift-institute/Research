# When Does an L3 Domain Package Need Its Own Cross-Platform Unifier Surface?

<!--
---
version: 1.0.0
last_updated: 2026-04-30
status: IN_PROGRESS
tier: 2
---
-->

## Context

Some L3 domain packages have their own cross-platform unifier surface (`swift-sockets` defines `Sockets.TCP.Connection` / `Sockets.TCP.Listener`; `swift-io` defines its own event-loop and completion machinery on top of `swift-kernel`'s unified primitives). Other L3 domain packages appear to consume `swift-kernel`'s unified surface directly without adding their own unifier (`swift-file-system` has no parallel `swift-files-unifier` package — it composes `swift-kernel` directly).

The 2026-04-20 socket-unifier migration (4 files moved from `swift-kernel` → `swift-sockets`) crystallized [PLAT-ARCH-021] as the rule for *where* cross-platform unification lives, but left open the question of *when* a domain L3 package needs its own unifier surface vs consuming `swift-kernel` directly.

This Doc scopes that question.

## Question

Under what conditions does an L3 domain package need its own cross-platform unifier surface (e.g., `swift-sockets`, `swift-io`), and under what conditions can the domain compose `swift-kernel`'s unified primitives directly without an intermediate unifier (e.g., `swift-file-system`)?

## Analysis

### Observed cases

| Domain L3 package | Has own unifier? | What it adds | Why |
|-------------------|------------------|--------------|-----|
| `swift-sockets` | Yes — `Sockets.TCP.*` types | Domain-specific value types (Connection, Listener) + RFC-typed addresses (IPv4, IPv6) | Domain has its own type vocabulary distinct from kernel primitives; cross-platform unification spans both kernel calls AND domain semantics |
| `swift-io` | Yes — `IO.Event.*`, `IO.Completion.*` types | Async I/O abstractions (event loops, completion futures) + scheduling policy | Async machinery is not a kernel primitive; it composes kernel primitives but adds non-kernel semantics |
| `swift-file-system` | No — composes `swift-kernel` directly | Domain-policy operations (atomic writes, directory traversal, permission models) using kernel primitives | Domain semantics are thin layers on top of kernel primitives; no separate type vocabulary needed |
| `swift-paths` | No — composes path primitives directly | Path manipulation (join, normalize, resolve) | Path is a vocabulary domain, not a unifier — paths don't dispatch syscalls |

### Hypothesis: domain-vocabulary threshold

The pattern that emerges from observed cases:

| Condition | Domain L3 needs own unifier? |
|-----------|-----------------------------|
| Domain introduces public types distinct from kernel primitives (e.g., `TCP.Connection`, `IO.Event.Channel`) | Yes — types need to live somewhere; that somewhere is the domain L3 unifier |
| Domain introduces public operations that compose kernel primitives but add policy/state (e.g., async completion machinery, retry strategies tied to domain semantics) | Yes — operations need a home with the right deps |
| Domain has spec deps distinct from kernel (RFC-typed values, ISO standards, vendor protocols) | Yes — per [PLAT-ARCH-021], spec deps belong in the domain L3 package |
| Domain semantics are "compose kernel primitives with domain policy" but no new types/ops/deps | No — compose `swift-kernel` directly; the domain L3 package is policy-only |

### Open analysis

| Question | Status |
|----------|--------|
| What's the threshold for "enough" domain vocabulary to justify a unifier? | TODO — count observed instances, compare against complexity |
| Does `swift-file-system` ever need its own unifier as it grows? | TODO — track over time as it adds more functionality |
| Are there hybrid cases (some operations through kernel-unifier, some through domain-unifier)? | TODO — document if observed |
| How does this compose with [PLAT-ARCH-008h]'s within-L3 sub-tiering matrix? | The matrix's L3-unifier sub-tier already accommodates multiple unifiers; this Doc's question is when to introduce a new one |

## Outcome

**Status**: IN_PROGRESS

**Held finding (operational)**: a domain L3 package needs its own cross-platform unifier surface when ANY of the following hold:

- The domain introduces public types distinct from kernel primitives.
- The domain introduces public operations that compose kernel primitives plus domain-specific policy (e.g., async/scheduling machinery, retry strategies bound to domain semantics).
- The domain has spec deps that don't belong in `swift-kernel` per [PLAT-ARCH-021].

When NONE of these hold, the domain L3 package composes `swift-kernel`'s unified surface directly without an intermediate unifier.

**Pending empirical work**:

1. Survey the existing domain L3 packages and classify each per the operational rule
2. Track new domain L3 packages as they're authored — does the rule predict the right architecture?
3. Document hybrid cases (if any) where the rule has fuzzy edges

**Tier classification**: Tier 2 per [RES-020] — cross-package, reversible precedent. The operational rule is sufficient for current decisions; deeper analysis would refine the threshold but does not unblock present work.

## References

- Reflection: [Research/Reflections/2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md](Reflections/2026-04-20-socket-unifier-rfc-composition-and-swift-sockets-migration.md)
- Skill rule: [PLAT-ARCH-021] (Domain-Specific Cross-Platform Unification Lives in Domain L3 Packages)
- Companion research: [ip-address-value-type-memory-layout.md](ip-address-value-type-memory-layout.md) — reasoning for why RFC-typed values stay in domain L3 (swift-sockets) rather than in `swift-kernel`
