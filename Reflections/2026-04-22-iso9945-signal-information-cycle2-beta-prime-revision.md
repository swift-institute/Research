---
date: 2026-04-22
session_objective: Cycle 2 implementation of Doc 3 (P2.3 #3 Signal.Action.Handler siginfo_t L2 wrapper); closed as PARTIAL via β' mid-cycle Decision #1 revision after IP5 empirically invalidated Option 1's signature retype under Swift @convention(c) @objc-representability.
packages:
  - swift-iso-9945
  - swift-institute/Audits
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Cycle 2 — ISO 9945.Kernel.Signal.Information: β' revision after @convention(c) representability block

## What Happened

Dispatched as Cycle 2 subordinate per `HANDOFF-layer-perfection-implementation.md § Active Cycle — Doc 3 Implementation`. Five skills loaded (platform, implementation, code-surface, modularization, supervise). Two pre-edit rule-#6 structural ambiguities escalated and authorized by the user-supervisor: (A) Signal.Action.swift 4-site co-edit scope for @convention(c) function-pointer bridges, (B) Package.swift `Kernel Memory Primitives` dep addition for `.fault: Kernel.Memory.Address?` access.

Eight edits executed per Doc 3 Option 1. Self-caught mid-edit: Handler.swift `replace_all` on `"public import "` → `"internal import"` had a trailing-space asymmetry producing `internal importDarwin/Glibc/Musl` with no space — caught via post-Edit read spot-check, fixed with 3 targeted edits before any subsequent edit fired, zero downstream impact.

IP5 build verification surfaced Doc 3 Q7's limitation. macOS + Docker Linux both failed with `'(…) -> Void' is not representable in Objective-C, so it cannot be used with '@convention(c)'` on the typed `UnsafeMutablePointer<Kernel.Signal.Information>?` parameter. I proposed `@convention(c, cType: "…")` as the Swift-approved override (grepping swift-syntax tests showed the syntax). Supervisor authorized as Option A with a cType-string fallback. Five cType/fold edits applied.

IP5 second build ran both fix classes: rebuild failed identically with the same representability error. Re-inspection of `swift/test/ClangImporter/clang-function-types.swift` clarified that `@convention(c, cType:)` annotations are Clang-importer-generated artifacts, NOT user-writable semantic overrides. Additionally, Information.swift's `public import Kernel_Memory_Primitives` pulled Tagged-derived `Optic.Prism<Enum, Part>` synthesis into the Signal target's module-wide namespace, adding static `.caseName` accessors that collided with `case .customInfo:` enum-pattern matches at Configuration.swift:85 + Handler.swift:99 (Linux only).

Escalated Option A's failure with options α/β/γ/δ/ε. Supervisor revised Doc 3 Principal Decision #1 to the β' shape (wrapper-only; revert signature retype; revert Signal.Action bridges; revert Package.swift dep; `.fault: UInt?` instead of `Kernel.Memory.Address?` to avoid the Optic cascade; keep Handler.swift import demotion drive-by).

Executed β' reverts. Immediately discovered: `internal import Darwin/Glibc/Musl` breaks the unchanged Handler.customInfo case signature (siginfo_t leak in public API requires public Darwin/Glibc/Musl imports). Reverted the import demotion too; Handler.swift unchanged from pre-Cycle-2 state.

Final scope: exactly one new file (`Information.swift` with `@safe` struct + `@unsafe public init(pointee:)` helper + 3 typed accessors — `.number`, `.sender`, `.fault`). Cycle 2 ships a Handler.swift edit count of zero.

Four iteration rounds on Linux-specific type issues: FPE_* → ILL_* → CLD_* → uniform `Int32(...)` wrap. glibc imports POSIX si_code anonymous-enum constants (FPE_*, ILL_*, CLD_*) as `Int`; Darwin imports them as `Int32`. Swift's case-expression type-matching rejects mixed types. Applied uniform `Int32(...)` wrap across all fault/sender case constants in all 3 platform branches (no-op on Darwin, explicit conversion on Linux).

IP5 final: macOS `swift build --build-tests` clean in 3.59s; Docker Linux swift:6.3.1 `swift build --build-tests` clean in 10.60s (no cache-resume race this cycle); downstream swift-foundations/swift-posix clean in 2.79s. Three commits: `2a5e5fe` (main — Information.swift only, +187 lines), `cd15bdd` (tracker — P2.3 #3 PARTIAL CLOSE + "Cycle 2 Doc 3 Option 1 empirical revision (β')" sub-entry), `891e935` (HANDOFF Cycle 2 § Status stamp).

### HANDOFF scan

In-session authority:
- `/Users/coen/Developer/swift-institute/Audits/HANDOFF-layer-perfection-implementation.md` — **annotated-and-left**. Stamped with Cycle 2 § Status via commit `891e935`. Cycle 3 (Doc 1 — P2.2 #1/#11) remains trigger-ready; the file is the canonical doc for future Cycle 3 open. Supervisor constraints #1–#6 verified end-to-end.

Out-of-session authority (leave untouched per [REFL-009] bounded-cleanup rule):
- `~25` other `HANDOFF*.md` files at `/Users/coen/Developer/`, `/Users/coen/Developer/swift-primitives/`, `/Users/coen/Developer/swift-foundations/`, etc. None of these describe work this session touched; no annotation applied.

## What Worked and What Didn't

**Worked — pre-edit rule-#6 escalation discipline.** Both ambiguities A (Action.swift co-edit) and B (Package.swift Memory dep) were surfaced before any source edit touched the related sites — matches the `/supervise` [SUPER-005] class-(c) pattern. User-supervisor authorized both with explicit caps (4-site scope cap on A; layering pre-check on B). When both were later reverted under β', no unauthorized touches remained.

**Worked — post-Edit read spot-check caught the replace_all typo.** The typo (`internal importDarwin` no-space) was invisible to the Edit tool's success response but trivially visible on a one-line file read. The supervisor's instruction #2 at IP4 ("Post-Edit verify before IP5") was load-bearing.

**Worked — mid-cycle Principal Decision revision gave a clean audit trail.** Rather than forcing β' as silent scope drift or abandoning the cycle, the supervisor's explicit Decision #1 revision at IP5-second-failure kept ground rules #1/#2 honestly tracked (as "Partially superseded" against β', not "Violated"). [SUPER-015] compression-at-pivot predicts this pattern; Cycle 2 demonstrates it in practice.

**Didn't work — @convention(c, cType:) interpretation.** I initially read the swift-syntax test coverage as confirming the annotation is user-writable. Only on IP5-second-failure did I re-inspect the ClangImporter test file, which clarified the annotation is importer-generated. A 30-second re-read up-front would have saved the 15-minute wrong path. Syntax-acceptance tests ≠ semantic-effect verification.

**Didn't work — Doc 3 Q7 scope was layout-only.** Q7 asked "is `MemoryLayout<Information>.stride == MemoryLayout<siginfo_t>.stride`?" Answer: yes. But the compiler requires a SEPARATE @objc-representability check on `@convention(c)` parameters — a check Doc 3 didn't evaluate. Necessary-not-sufficient is the compact description.

**Didn't work — cross-platform si_code type divergence not anticipated upfront.** Four iteration rounds (FPE → ILL → CLD → uniform) is 3 rounds too many. A Linux-native grep for `.si_code` patterns or a broader defensive `Int32(...)` wrap at initial write would have collapsed this to one round.

## Patterns and Root Causes

**Pattern 1 — Q-analysis can be necessary-not-sufficient.** Doc 3 Q7 was correctly answered on the dimension it framed (layout). The compiler's constraint surface had a dimension Q7 didn't frame (representability). This is a known pitfall in deliberation research: the analyst addresses the question they asked, not the question they needed to ask. For Swift investigations of patterns that touch the multi-attribute type surface (@safe, @unsafe, @frozen, @_rawLayout, @objc, @convention(c), Sendable, ~Copyable, ~Escapable), a checklist of dimensions would prevent this class of omission. "Layout-compatible + @objc-representable + Sendable-safe + ownership-sound" is the minimal matrix for the typed-pointer-in-@convention(c) pattern. Doc 3's Q7 covered only column 1.

**Pattern 2 — Ecosystem imports carry hidden namespace cascades.** `public import Kernel_Memory_Primitives` is a one-line change; its effect includes synthesized `Optic.Prism<Enum, Part>.caseName` extensions on every enum declared in the importing module. This is not documented anywhere in the ecosystem, but a grep across `Tagged<…>` uses would find every instance. The class of risk is broader than Memory.Address specifically — any Tagged-bearing primitive that ships Optic conformances will trigger this at consumer sites that declare enums. Analogous pattern: transitive re-exports via `@_exported public import` silently widen public API surface. The general lesson is that `public import`'s effect is not local to the importing file; it affects the entire compilation unit's name-resolution graph.

**Pattern 3 — Cross-platform C-import type divergence is empirical territory.** Darwin, Glibc, and Musl each import C anonymous enums differently depending on the enum's underlying declaration context. FPE_* is in one anonymous enum on glibc that Swift imports as `Int`; SEGV_* is in a different anonymous enum that imports as `Int32`. These decisions are not specified by Swift nor documented by the libc maintainers. Empirically knowable only via Docker Linux iteration. The defensive coding response: `Int32(...)` wrap on all si_code-like case constants in `switch` expressions where the switched value is Int32-typed.

**Pattern 4 — Iteration rounds on Linux-specific issues accurately price unverified spec gaps.** The 4 iteration rounds (FPE → ILL → CLD → uniform) weren't bugs — they were incrementally-surfaced facts about the glibc ABI. The cost is real but accurately-priced: 4 Docker Linux builds at ~10s each after cache-resume. Pre-paying the cost via defensive up-front `Int32(...)` wrap would have cost ~1 edit batch. Marginal tradeoff favors pre-paying; worth codifying.

**Pattern 5 — Revert-as-zero-diff is a legitimate cycle outcome.** Cycle 2's final tracked-file diff is zero (Information.swift is new, not modified); the 8 original edits + 5 Option-A edits + various reverts net to no tracked-file modifications beyond the new file. This looks unproductive but accurately reflects the scope: the investigation work (what doesn't work, why, what survives) is captured in the main commit body's `[SUPER-015] Notes` and the tracker's "Cycle 2 Doc 3 Option 1 empirical revision (β')" sub-entry. The durable artifacts are the learning and the PARTIAL close, not the code volume.

## Action Items

- [ ] **[skill] platform**: Add requirement for `@convention(c)` parameter representability. Pure Swift structs (including `@safe` / layout-compatible wrappers) are NOT @objc-representable and cannot appear as `UnsafeMutablePointer<T>?` parameters in `@convention(c)` function types. `@convention(c, cType: "…")` is Clang-importer-generated and does NOT override this check for user-written types. When a typed ecosystem wrapper is needed for a C-callback parameter: use `OpaquePointer?`, `UnsafeMutableRawPointer?`, or retain the imported-C-struct pointer — and expose typed access via a separate helper init on the wrapper (the β' pattern established by Cycle 2). Cite `swift/test/ClangImporter/clang-function-types.swift` as the authoritative reference. [PLAT-ARCH-005a] Pattern 2 should reference this constraint explicitly.

- [ ] **[research] swift-institute**: Audit Optic.Prism namespace cascade across the ecosystem. Investigate every module that `public import`s a Tagged-bearing primitive (swift-kernel-primitives/`Kernel.Memory.Address`, swift-memory-primitives/`Memory.Address`, possibly others). Document: (1) which Tagged types ship Optic.Prism conformances; (2) which consumer modules declare enums that could collide with case-pattern matches; (3) workaround patterns (`case .caseName(_):` wildcard, demoted `internal import`, or fully-qualified `case Module.Type.caseName:` match). Target: `swift-institute/Research/optic-prism-namespace-cascade.md` as a consultation artifact before future sessions add `public import` of Tagged modules to enum-declaring targets.

- [ ] **[skill] platform**: Add cross-platform guidance for C anonymous-enum constant type divergence. POSIX si_code subgroups (FPE_*, ILL_*, SEGV_*, BUS_*, CLD_*, SI_*) import as `Int` on glibc but `Int32` on Darwin; `Int32(...)` wrap is required at case-match sites when the switched value is Int32-typed. Recommend: default to explicit `Int32(...)` wrap on all si_code-like case constants in switches over Int32-typed values. Sits alongside the existing platform skill's `#if canImport` field-access-path guidance for `siginfo_t` / `sigaction` union-member access.
