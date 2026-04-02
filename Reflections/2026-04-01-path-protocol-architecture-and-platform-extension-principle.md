---
date: 2026-04-01
session_objective: Implement L1 path decomposition primitives (parentBytes, lastComponentBytes, appending) per handoff
packages:
  - swift-path-primitives
  - swift-iso-9945
  - swift-windows-primitives
  - swift-institute
status: processed
processed_date: 2026-04-01
triage_outcomes:
  - type: skill_update
    target: platform
    description: "Add guidance on when Type.Protocol pattern applies vs ad-hoc extensions — threshold is 2+ platform implementations of same API surface"
  - type: research_topic
    target: L1 Type.Protocol candidate audit
    description: "Audit L1 primitives for additional Type.Protocol candidates beyond Path — String_Primitives.String is first candidate"
  - type: package_insight
    target: swift-path-primitives
    description: "Path.init(_ span:) uses no label — canonical pattern for ~Escapable to ~Copyable construction"
---

# Path.`Protocol` Architecture and Platform Extension Principle

## What Happened

Session began with a handoff to implement Phase 4a path decomposition in `swift-path-primitives`. Initial approach: add `Path.separator`, `Path.isSeparator`, and decomposition methods directly to `Path.View` with `#if os()` conditionals.

User rejected this: platform-specific logic should live in platform packages, not primitives. This triggered a significant architectural redesign:

1. **Explored platform packages** — `swift-iso-9945` (POSIX, in `swift-iso/`) and `swift-windows-primitives` both already depend on `Kernel_Primitives` which re-exports `Path_Primitives`. No new dependencies needed.

2. **Discovered `Kernel.Path = Tagged<Kernel, Path_Primitives.Path>`** — the phantom-type wrapper means `Kernel.Path.view` returns raw `Path.View`. Extensions on `Path.View` in platform packages are visible through the re-export chain.

3. **User proposed `Path.Protocol`** to prevent API divergence between platform implementations. Initial concern: `~Escapable` protocol conformance with `@_lifetime` requirements might not compile. Two experiments proved it works:
   - `escapable-protocol-navigation` (7/7 single-module)
   - `escapable-protocol-cross-module` (6/6 multi-module — exact target architecture)

4. **Key insight: `Path` is not generic, so protocol nests directly** — no hoisting needed. The `Type.Protocol` pattern with backtick escaping is established in the ecosystem.

5. **Added [PLAT-ARCH-008c]** to platform skill: "Platform Extensions Over Primitive Conditionals" — L1 primitives stay unconditionally platform-agnostic; platform packages extend lower-layer types.

No implementation code was written. Session was entirely architectural design + experiment validation.

## What Worked and What Didn't

**What worked**:
- User's architectural instinct was correct at every turn: platform packages over `#if os()`, protocol over ad-hoc extensions, language semantics over identifier labels (`init(_ span:)` not `init(copying:)`), direct nesting over hoisting
- Experiments validated the full pattern quickly — 13 variants across 2 experiments, all CONFIRMED
- The `Kernel_Primitives` re-export chain made the architecture zero-cost in dependency terms

**What didn't work**:
- Initial instinct to put everything in path-primitives with conditionals — would have violated the platform architecture
- Initial assumption that `~Escapable` protocol conformance was risky — wrong, Swift 6.3 handles it cleanly
- Proposed `init(copying:)` label — user correctly identified that ownership semantics make the label redundant

## Patterns and Root Causes

**"Package boundary as platform boundary"**: This is the deeper principle behind [PLAT-ARCH-008c]. When a platform package only compiles on one platform, every line in it is implicitly platform-conditional. No `#if os()` needed — the build system IS the conditional. This eliminates an entire class of conditional-compilation bugs (wrong branch, missing platform, stale conditional).

**Protocol-driven platform conformance**: The `Type.Protocol` pattern generalizes beyond Path. Any L1 type whose behavior varies by platform is a candidate. The protocol ensures API sync at compile time; platform packages provide the implementation. This is a form of dependency inversion: the primitive defines the contract, the platform fulfills it.

**Experiment-first for compiler edge cases**: The `~Escapable` protocol concern was resolved in minutes by experiment. Without the experiment, we would have either (a) avoided the protocol approach out of caution, or (b) spent time reasoning about compiler internals. The experiment was faster and more authoritative than either alternative.

## Action Items

- [ ] **[skill]** platform: Add guidance on when `Type.Protocol` pattern applies vs when ad-hoc extensions suffice (threshold: 2+ platform implementations of same API surface)
- [ ] **[research]** Audit L1 primitives for additional `Type.Protocol` candidates — `String_Primitives.String` is the first candidate (see HANDOFF-primitive-protocol-audit.md)
- [ ] **[package]** swift-path-primitives: `Path.init(_ span:)` uses no label — document this as the canonical pattern for `~Escapable → ~Copyable` construction across the ecosystem
