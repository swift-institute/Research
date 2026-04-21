---
date: 2026-04-21
session_objective: Extract the bare `public enum Kernel {}` namespace out of Kernel Primitives Core into its own product-level target so downstream extenders stop paying full Core transitive weight to extend the namespace.
packages:
  - swift-kernel-primitives
  - swift-primitives (superrepo)
  - swift-iso-9945
  - swift-linux-foundation/swift-linux-standard
  - swift-foundations/swift-kernel
  - swift-institute/Skills/modularization
status: processed
processed_date: 2026-04-21
triage_outcomes:
  - type: skill_update
    target: modularization
    description: [MOD-017] Namespace-Only Target, mandatory for empty top-level namespaces; includes layer-invariant naming exception to [MOD-012]
---

# Namespace-Only Target Pattern — kernel-primitives case study and [MOD-017] codification

## What Happened

Every downstream extender of `enum Kernel` was paying for 10 external re-exports to touch one declaration. The extender set is broad: `swift-iso-9945`, `swift-linux-standard` (18 files), `swift-darwin-standard`, `swift-windows-standard`, plus L3 composers (`swift-foundations/swift-kernel`, `swift-posix`, `swift-darwin`). Each imports `Kernel_Primitives_Core` and transitively acquires Binary, CPU, Cardinal, Dimension, Identity, Time, String, Error, ASCII, and Memory — none of which the pure-namespace extender needs.

Case study scope was the minimum viable pattern: move `Kernel.swift` (a bare `public enum Kernel {}`) into a new `Kernel Namespace` target with zero deps, published as a library product. `Kernel Primitives Core` gains `"Kernel Namespace"` as its first dependency and adds `@_exported public import Kernel_Namespace` at the top of its `exports.swift`, so the module name `Kernel` remains visible through every existing Core-importing site. No downstream source edits were required to keep the tree green.

Validation: clean build + test of `swift-kernel-primitives` plus clean spot-builds of `swift-iso-9945`, `swift-linux-standard`, and `swift-foundations/swift-kernel` all green. A transient "linker missing `Kernel_Primitives_Core.Kernel` metadata" error on the first iso-9945 build turned out to be parallel-agent interference on the shared workspace — reproduced clean on isolation.

Naming converged on the unsuffixed form `Kernel Namespace` rather than `Kernel Namespace Primitives`. The module name is layer-invariant: the same `enum Kernel` is extended at L1 (primitives variants), L2 (standards), and L3 (foundations). Carrying the `-Primitives` suffix at L1 only would force the downstream import site to change across layers for no semantic reason. This is a deliberate deviation from [MOD-012]'s layer-suffix rule, documented in-rule rather than as an external exception.

The user's ask for codification was explicit: mandatory for all empty top-level namespaces in a first pass, with non-empty cases (e.g., namespaces that declare typealiases or static members inline) deferred until the empty cases are migrated.

## What Worked and What Didn't

**Worked**:

- Minimal-blast-radius design. Moving exactly one file, adding one `@_exported` line, and declaring the new target with empty `dependencies: []` meant zero downstream code churn. The re-export path preserves every existing call site.
- Layer-invariant naming. Dropping `-Primitives` was initially ambiguous — it deviates from [MOD-012]. Writing out the reasoning (same `enum Kernel` extended at every layer → same import name at every layer) made the exception self-justifying, and it became the most defensible naming choice rather than a soft deviation.
- Skill update scoped to "empty" namespaces first. The populated-namespace case (Kernel.File carrying types with external deps, or top-level namespaces with inline typealiases/statics) has real trade-offs that deserve their own pass. Not bundling them keeps the first rule precise.

**Didn't work**:

- First iso-9945 spot-build produced a spooky link-time missing-metadata error for `Kernel_Primitives_Core.Kernel` that looked like a genuine regression. Stash+baseline reproduced it cleanly, which inverted the diagnosis — it was transient state, not a regression. Re-running on an isolated tree passed. Cost ~10 minutes of investigation on a non-issue. The lesson: on a multi-agent shared workspace, reproduce once against a known-clean state before burning time on a "regression".
- Nearly classified the update as Additive when it's arguably Breaking under [SKILL-LIFE-003]: existing packages with bare `enum X {}` declarations buried in Core don't comply with the new mandatory rule until they're migrated. Recording as Additive with a migration inventory (next task) separates rule-introduction from rule-enforcement — cleaner than calling it Breaking and demanding per-package alignment up front.

## Follow-ups

- Inventory all bare top-level namespace files in swift-primitives that qualify for first-pass migration. Expected candidates: any package whose Core has a standalone `{Domain}.swift` with `public enum {Domain} {}` and nothing else. *(Done — see `swift-institute/Audits/mod-017-namespace-extraction-inventory.md`; 14 packages qualify.)*
- Downstream pure-extenders (`Linux.Kernel.swift`, `Darwin.Kernel.swift`, `Windows.Kernel.swift`, the four `@_exported public import Kernel_Primitives_Core` lines in L3 `exports.swift` files) become one-line migration opportunities once the first-pass inventory lands.

## Refinement — rule reframed after the first inventory (2026-04-21)

User pushback on the narrow "MUST be empty" framing of the first-pass rule produced a sharper version, landed the same day:

- The **dependency invariant** (Namespace targets depend only on other Namespace targets) is the hard, non-negotiable rule. This is what protects the universally-cheap-to-import property and is what makes the transitive-weight payoff durable.
- The **content policy** (what goes in Namespace) is case-by-case, not a fixed rule. The conservative default is the bare `enum {Domain} {}`; additional declarations MAY be placed in Namespace when they respect the invariant AND an extender need justifies the added surface. When in doubt, keep content in Core — extracting later is cheap, deciding prematurely is not.
- The rule now applies to every top-level namespace, not just "empty" ones. The inventory's QUALIFIES/POPULATED split still drives the first-pass migration plan (migrate the bare-enum cases now; defer populated cases until extender need emerges), but the underlying rule no longer uses "empty" as a trigger condition.

Skill text at `swift-institute/Skills/modularization/SKILL.md` [MOD-017] reflects the refined framing. The Kernel case study is unchanged and remains the reference implementation — it happens to be a bare-enum case, which is the conservative default under the new framing as well.
