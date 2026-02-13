---
date: 2026-02-12
session_objective: Implement multi-phase remediation plan for swift-stack-primitives and fix pre-existing swift-buffer-primitives test failures
packages:
  - swift-stack-primitives
  - swift-buffer-primitives
status: processed
processed_date: 2026-02-13
triage_outcomes:
  - type: skill_update
    target: implementation
    description: Strengthen [IMPL-052] — unbounded variants MUST NOT co-exist with bounded on static-capacity types
  - type: skill_update
    target: existing-infrastructure
    description: Add audit guidance to [INFRA-105] — subtractive fix, not additive
  - type: package_insight
    target: swift-buffer-primitives
    description: Audit Slab variants for remaining unbounded Bit.Index parameters
---

# Stack/Buffer Remediation — Bounded Indices as Sole Canonical API

## What Happened

Implemented a 7-phase remediation plan for `swift-stack-primitives` (delegating forEach/truncate to buffer, removing bare Int APIs, replacing custom Iterators with buffer Iterator typealiases, adding bounded subscripts to Stack.Static). Added `truncate(to:)` infrastructure to all four `Buffer.Linear` variants. All 78 stack tests and 333 buffer tests pass.

During the buffer test fixes, three pre-existing `Buffer.Slab` test compilation errors surfaced. Fixing `Buffer.Slab.Inline` tests revealed a design question: `isOccupied(at:)` accepted unbounded `Bit.Index` while `insert`/`remove`/`peek`/`firstVacant` all used `Bit.Index.Bounded<wordCount>`. Three incorrect fix attempts were made before arriving at the principled solution.

## What Worked and What Didn't

**Worked**: The stack remediation plan was precise — all phases compiled and passed on first attempt. Buffer `truncate(to:)` infrastructure followed established patterns (heap uses bulk `storage.deinitialize(range:)`, inline's `deinitialize(range:)` already clears tracking bits). Iterator forwarding to buffer's Iterator types was clean.

**Didn't work**: Three successive approaches to fixing `Buffer.Slab.Inline.isOccupied` were rejected:

1. **Cast literals at call sites** (`0 as Bit.Index.Bounded<4>`) — treats symptoms, leaves unbounded API in place
2. **Add bounded overload alongside unbounded** — creates overload ambiguity, leaves non-canonical API present
3. **Keep unbounded, widen at call sites** (`Bit.Index(slot)`) — pushes conversion to caller, opposite of [IMPL-010]

The correct approach: **remove the unbounded variant entirely**, make `Bit.Index.Bounded<wordCount>` the sole public API, widen inside the method body when delegating to `header.isOccupied(at: Bit.Index)`. `Buffer.Slab.Small` narrows at its delegation boundary.

Confidence was low on the first two attempts because the instinct was to preserve backwards compatibility rather than enforce the principled API.

## Patterns and Root Causes

The core pattern: **on static-capacity types, bounded indices are not an "also" — they are the only API**. [IMPL-052] says bounded indices must "propagate to every call site that touches a position." The corollary, which was not explicit enough in the skill, is that unbounded variants on static-capacity types should not exist at all. They are not a fallback — they are a violation.

This connects to a deeper principle: when two API variants exist (bounded and unbounded) on a type where bounds are statically known, the unbounded variant is technical debt. It doesn't just miss an optimization — it actively undermines the type's contract. The type knows its capacity at compile time; exposing unbounded access discards that knowledge.

The three-attempt convergence also reveals a pattern in AI remediation: the instinct to add (overloads, casts, wrappers) rather than remove. The principled fix was subtractive — delete the unbounded variant. Each additive attempt was less principled than the last. This mirrors [IMPL-000] call-site-first design: the ideal call site has zero conversions, which means the API must accept the canonical type directly.

Stale `.build` directories caused a spurious linker failure (`Bit_Vector_Primitives` undefined symbols) that wasted investigation time. Removing `.build` is now the first diagnostic step.

## Action Items

- [ ] **[skill]** implementation: Strengthen [IMPL-052] to explicitly state that unbounded index variants MUST NOT exist on static-capacity types — bounded is the sole public API, not an overload alongside unbounded. The current wording ("MUST use Bounded<N>, not unbounded Index<Element>") could be read as "prefer" rather than "replace."
- [ ] **[skill]** existing-infrastructure: Add [INFRA-105] guidance that when auditing static-capacity types, the finding is not "add bounded overload" but "replace unbounded with bounded" — subtractive, not additive.
- [ ] **[package]** swift-buffer-primitives: Audit remaining `Buffer.Slab.Inline` and `Buffer.Slab.Bounded` public APIs for unbounded `Bit.Index` parameters that should be `Bit.Index.Bounded<wordCount>` (e.g., `isOccupied` was fixed, but a systematic sweep may reveal others on Bounded/Small variants).
