---
date: 2026-04-01
session_objective: Audit swift-link-primitives against code-surface, implementation, modularization skills and fix violations; add tests
packages:
  - swift-link-primitives
status: pending
---

# Link Primitives Audit — Compound Identifier Blind Spot and Test Harness

## What Happened

Picked up from HANDOFF.md to audit the newly extracted swift-link-primitives package. Loaded five skills (code-surface, implementation, modularization, memory-safety, primitives) and systematically checked all 5 source files.

Initial audit found one violation: `@unchecked Sendable` on `Link.Node` where plain `Sendable` suffices ([MEM-SEND-004]). Traced the Sendable chain through `Ordinal: Sendable` -> `Tagged: Sendable` -> `Index: Sendable` -> `InlineArray: Sendable` to confirm. Fixed.

User challenged the "0 findings" on compound identifiers. Re-examination found `insertAfter(_:after:header:_:)` where `After` in the method name is redundant with the `after:` parameter label. Renamed to `insert(_:after:header:_:)`. Zero external call sites made this safe. Also flagged `unlinkFirst`/`unlinkLast`/`linksPointer` as compound but accepted under [IMPL-024] (static implementation layer consumed by downstream Property.View code).

Added 37 tests across 3 suites. The test harness for topology operations required a `@safe` Pool class wrapping an `UnsafeMutablePointer` buffer, with `unsafe` inside every `linksAt` closure — strict memory safety enforcement caught this immediately.

Initialized swift-link-primitives as its own git repo (was initially committed to the superrepo by mistake).

## What Worked and What Didn't

**Worked**: The Sendable chain verification was thorough — tracing through four packages to confirm the `@unchecked` was unnecessary. The test harness design using `Pool.collect()` for assertion made topology tests readable.

**Didn't work**: First-pass audit dismissed all compound identifiers under [IMPL-024] without examining each one individually. The `insertAfter` case was clear — the method name duplicates the parameter label. User had to push back to surface this. The distinction between "compound name in static layer" (permitted) and "compound name redundant with label" (violation regardless of layer) should have been caught on first pass.

Also: first test compilation failed because `unsafe` doesn't propagate into closures. Should have anticipated this from [MEM-SAFE-002] ("unsafe does NOT propagate into closures").

## Patterns and Root Causes

The compound identifier blind spot reveals a tendency to apply exceptions too broadly. [IMPL-024] permits compound names in the static layer, but this doesn't override the deeper principle that redundancy between method name and parameter labels is always a defect. The exception is about *where* compound names are acceptable, not a blanket permission for any compound name. The correct mental model: [IMPL-024] relaxes naming for static internals, but [API-NAME-002]'s prohibition on redundant naming still applies universally.

This is the same over-application pattern seen in other audits: a rule exception is read as "this area is exempt" rather than "this specific tension is resolved." Exceptions narrow; they don't eliminate.

## Action Items

- [ ] **[skill]** code-surface: Add note to [API-NAME-002] or [IMPL-024] clarifying that parameter-label redundancy is a violation independent of static layer exception
- [ ] **[skill]** memory-safety: Add note to [MEM-SAFE-002] reminding that `@safe` on test harness classes encapsulating unsafe storage follows the same [MEM-SAFE-021] pattern as production code
- [ ] **[package]** swift-link-primitives: Consider renaming `linksPointer` to `pointer` — stutter with `Link` namespace, but deferred due to 8 external call sites across buffer-primitives and async-primitives
