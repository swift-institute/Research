# Within-L3 Sub-Tiering — Composition Rules and Options Matrix

Date: 2026-04-25
Scope: ecosystem-wide (the 13 platform-stack audit packages + 5 peer L3 packages they import — swift-systems, swift-io, swift-threads, swift-environment, swift-ascii)
Audit findings: P2.11 (swift-darwin/linux → swift-posix lateral), P2.12 (swift-file-system → swift-io/threads/environment/ascii lateral), promoted from META M-01/M-02 in `swift-institute/Audits/platform-compliance-2026-04-21.md` per dispatch principal review 2026-04-25
Status: **STAMPED 2026-04-26 — Hybrid B+C with explicit 3-sub-tier enumeration; swift-posix stays L3-policy; swift-systems re-classified as L3-unifier; Pattern 3 (swift-windows → swift-systems) flagged as violation requiring refactor**

Decision section appended at end of doc (`§ Stamped Decision`); options matrix retained above as the deliberation record.

This document surveys options for resolving the lateral L3 → L3 composition gap that produced two audit findings (P2.11 + P2.12) and surfaced a third un-flagged pattern during empirical census. The framing is unified: P2.11 and P2.12 are presented as evidence-instances of a single deeper question — **within-L3 sub-tiering is implicit, and inter-tier composition rules are codified for one direction only**. Each option below names the principal-stamp moment.

---

## Problem Statement

`/platform`'s [PLAT-ARCH-001] codifies three layers (Primitives / Standards / Foundations). Within Foundations (L3), three operational sub-tiers exist in practice but are not named in the canonical layer specification:

- **L3-cross-platform-unifier**: `swift-kernel`, `swift-strings`, `swift-paths`. Cross-platform unification surface; consumers `import Kernel` / `import Strings` / `import Paths`.
- **L3-platform-policy**: `swift-posix`, `swift-darwin`, `swift-linux`, `swift-windows`. Policy-normalized wrappers (EINTR retry, partial-IO loop, error normalization) over L2 spec packages.
- **L3-domain**: `swift-file-system`, `swift-io`, `swift-threads`, `swift-environment`, `swift-ascii`, `swift-systems`. Domain-specific composition over unifier + utility.

[PLAT-ARCH-008e] codifies one composition direction explicitly: **L3-cross-platform-unifier MUST compose over L3-platform-policy peers**. Every other within-L3 composition direction is uncodified.

[ARCH-LAYER-001] strict reading forbids lateral within-layer dependencies. P2.11 and P2.12 surface as audit findings because lateral patterns exist in practice — they are structurally intentional but unauthorized by any extant rule. The strict-reading interpretation produces audit pressure to either (a) restructure away the lateral patterns, or (b) extend [PLAT-ARCH-*] to authorize them.

The current audit dispatch logged P2.11 + P2.12 as P-series HIGH findings with explicit remediation routes "(a) restructure OR (b) extend [PLAT-ARCH-*]". This Doc settles WHICH of those routes — and the structural shape of the route — before any remediation cycle dispatches.

---

## Empirical Census (per [HANDOFF-021])

Within-L3 cross-package imports across the 13 platform-stack audit packages, surveyed 2026-04-25 via `grep -rhE '^[[:space:]]*(@_exported public |@_spi.*public |@preconcurrency public |public |internal |package )?import [A-Za-z_]+\b'` filtered to L3 module names (Kernel, POSIX_Kernel, Darwin_Kernel, Linux_Kernel, Windows_Kernel, Strings, Paths, IO, Executors, Thread_*, Environment, ASCII, Systems, File_System). Re-exports of own-package targets filtered out — only true cross-package L3 → L3 imports retained.

| FROM (sub-tier) | TO (sub-tier) | Site | Pattern |
|-----------------|---------------|------|---------|
| swift-kernel (unifier) | swift-darwin/linux/windows/posix (platform-policy) | `Kernel/exports.swift` umbrella re-exports | **Pattern 1** ✓ codified [PLAT-ARCH-008e] |
| swift-darwin (platform-policy) | swift-posix (platform-policy) | `Darwin Kernel/exports.swift:31-35` (`import POSIX_Kernel_File/Directory/Memory/Signal/Process` etc.) | **Pattern 2** P2.11 — un-codified |
| swift-linux (platform-policy) | swift-posix (platform-policy) | `Linux Kernel IO Uring/Kernel.IO.Uring+Supported.swift:16` (`import POSIX_Kernel`) | **Pattern 2** P2.11 — un-codified |
| swift-windows (platform-policy) | swift-systems (domain) | `Windows Kernel/Windows.Thread.Affinity.swift:16` (`public import Systems`) | **Pattern 3** UN-FLAGGED — surfaces from census |
| swift-file-system (domain) | swift-kernel/strings/paths (unifier) | `File.Name.swift`, `File.System.*.swift` (`public import Kernel`, `Paths`, `Strings`) | **Pattern 4** assumed-authorized [PLAT-ARCH-008d] |
| swift-file-system (domain) | swift-io/threads/environment/ascii (domain) | Multiple files (`public import IO/Executors/Thread_Actor/Thread_Pool`; `import ASCII/Environment`) | **Pattern 5** P2.12 — un-codified |
| swift-paths (unifier, TEST scope) | swift-kernel (unifier) | `swift-paths/Package.swift` test-target dep (`Kernel Core` test-only) | **Pattern 6** TEST-SCOPE — laxer; not a finding |

Six distinct within-L3 composition patterns. **One codified** ([PLAT-ARCH-008e]). **One assumed-authorized** ([PLAT-ARCH-008d] frames L3-domain `#if os()` policy without explicitly authorizing peer composition over L3-unifier — but the entire purpose of L3-domain packages requires it). **Three un-codified** (P2.11, Pattern 3, P2.12). **One out-of-scope** (TEST-only).

The census surfaces Pattern 3 (L3-platform-policy → L3-domain via swift-windows → swift-systems) as a previously un-flagged instance of the same gap. It was not on the audit's P-series radar because the windows L3 audit didn't focus on Systems composition — but it sits in the same matrix-cell as P2.11 conceptually (platform-policy composing peer-L3 of a different sub-tier).

---

## The Question

**What's the within-L3 composition rule across all 9 directional sub-tier pairs?**

The full 3×3 directional matrix (each cell = "FROM source-tier → TO target-tier"):

|                                   | → L3-unifier | → L3-platform-policy | → L3-domain |
|-----------------------------------|:------------:|:--------------------:|:-----------:|
| **FROM L3-unifier**               |   (peer)     |   ✓ codified [PLAT-ARCH-008e] | (none observed) |
| **FROM L3-platform-policy**       |   (none observed)  |   un-codified (P2.11) | un-flagged (Pattern 3) |
| **FROM L3-domain**                |   assumed-authorized [PLAT-ARCH-008d] | (none observed) | un-codified (P2.12) |

7 of 9 cells have known status. The remaining 2 (FROM unifier → unifier-peer; FROM platform-policy → unifier; FROM domain → platform-policy) are unobserved-in-current-ecosystem-source — they could happen but don't.

**Sub-question**: should the doc define rules for unobserved cells as well, or leave them undefined until evidence surfaces? This Doc's census is empirical; recommendation is to codify rules for **observed cells** + note the unobserved cells as "left to future ecosystem evolution."

---

## Sub-tier Enumeration

Today's L3 sub-tiering is implicit. Codifying it explicitly is this Doc's primary contribution regardless of which option is selected. Proposed enumeration:

| Sub-tier | Role | Packages |
|----------|------|----------|
| L3-cross-platform-unifier | Cross-platform unification surface; consumers see `import Kernel` / `import Strings` / `import Paths`. Composes downward over L3-platform-policy + L1/L2. | swift-kernel, swift-strings, swift-paths |
| L3-platform-policy | Policy-normalized wrappers (EINTR retry, partial-IO loop, error normalization) over L2 spec packages. Per-platform: swift-darwin/linux/windows; per-spec-shared: swift-posix. | swift-posix, swift-darwin, swift-linux, swift-windows |
| L3-domain | Domain-specific composition over unifier + utility. Each package serves one domain (file-system, IO scheduling, thread synchronization, environment access, etc.). | swift-file-system, swift-io, swift-threads, swift-environment, swift-ascii, swift-systems |

The sub-tier classifications above match practice but have not been written into [PLAT-ARCH-*]. Codifying them is necessary even before any composition-rule decision; without explicit sub-tiers, the composition matrix has no labeled axes.

**Sub-tier candidate questions**:

1. **Is swift-posix actually L3-platform-policy?** swift-posix differs from its sub-tier peers — it's POSIX-shared (consumed by swift-darwin AND swift-linux, both POSIX platforms), not platform-specific. Some options below treat this as a mis-classification (swift-posix is conceptually L2.5 or "shared platform-policy") rather than a peer.
2. **Is swift-systems L3-domain?** It provides system-info queries (NUMA, memory totals, processor count). Domain-classification fits, but the system-info "domain" is thin — could equally be a utility consumed by many packages.
3. **Is swift-ascii L3-domain?** It's a value-classification namespace over UInt8 with no ownership type. Closer to L2 (spec-implementing) than L3 — could re-tier downward.

These classification edge cases inform Options C and D below.

---

## Options Matrix

Four options. Each option is evaluated against P2.11 and P2.12 + Pattern 3 (the un-flagged Windows → Systems lateral).

### Option A — Codify carve-out via explicit composition rules

Add `[PLAT-ARCH-008h]` (and possibly `[PLAT-ARCH-008i]` for L3-domain) as additive sub-rules to [PLAT-ARCH-008e]. Each cell of the 3×3 matrix gets an explicit rule. No code restructure; the lateral patterns become permitted-by-rule.

**Per-finding cell**:

| Finding | Resolution under (A) |
|---------|----------------------|
| **P2.11** swift-darwin/linux → swift-posix | New rule: "L3-platform-policy peer composition is permitted when one peer provides cross-platform-shared policy semantics (POSIX is shared by Darwin and Linux). Composition flows from platform-specific → platform-shared, never the reverse." swift-posix is the canonical "platform-shared" instance. RESOLVED via rule extension; no code change. |
| **P2.12** swift-file-system → swift-io/threads/environment/ascii | New rule: "L3-domain peer composition is permitted within the same domain cluster (e.g., file-system + io + threads + executors + environment + ascii form one cluster). Each cluster's composition rules SHOULD be documented in a cluster manifest." RESOLVED via rule extension; no code change. |
| **Pattern 3** swift-windows → swift-systems | Either (a-1) re-classify swift-systems as L3-platform-policy (it's system-information; consumed by swift-windows for NUMA discovery — this is platform-info, not domain) — Pattern 3 collapses to L3-platform-policy → L3-platform-policy peer (Pattern 2's class), resolved by the same rule. Or (a-2) the new "L3-platform-policy → L3-domain" rule explicitly authorizes platform-policy composing domain-utilities. |

**Cost**: lowest. Pure rule additions to `/platform` skill. No code change. Per-package audit.md row text updated locally to reflect "RESOLVED-via-rule-codification."

**Risk**: convention-only. The compiler / SPM does not enforce "only POSIX-shared composition allowed." A future platform-policy package importing a platform-specific peer (swift-darwin importing swift-linux, e.g.) would compile cleanly; only review-time caught. Per `feedback_structural_fix_preference.md` auto-memory, this is the dispreferred mechanism.

### Option B — Explicit sub-tiering with hierarchical composition

Promote the implicit sub-tiers to first-class layers. The [PLAT-ARCH-001] table grows from 5 layers to 7 (or L3 splits into L3.1 / L3.2 / L3.3). Composition is **strictly hierarchical** within L3: L3.3 (domain) may compose L3.2 (unifier) which may compose L3.1 (platform-policy + utility). Lateral within the same sub-tier remains forbidden.

| Layer | Role | Packages | Composes |
|-------|------|----------|----------|
| L3.3 | domain | swift-file-system, swift-io, swift-threads, swift-environment, swift-ascii, swift-systems | L3.2 + L3.1 + L1/L2 |
| L3.2 | unifier | swift-kernel, swift-strings, swift-paths | L3.1 + L1/L2 |
| L3.1 | platform-policy + shared-policy | swift-posix, swift-darwin, swift-linux, swift-windows | L1/L2 |

**Per-finding cell**:

| Finding | Resolution under (B) |
|---------|----------------------|
| **P2.11** swift-darwin/linux → swift-posix | swift-darwin / swift-linux / swift-posix are all L3.1. Strict hierarchical composition forbids L3.1 → L3.1. Does not resolve P2.11 — remediation requires either (B-extension) sub-split L3.1 further (e.g., L3.1a "platform-shared", L3.1b "platform-specific"), OR (Option C) re-tier swift-posix to L2.5. |
| **P2.12** swift-file-system → swift-io/threads/environment/ascii | swift-file-system is L3.3. swift-io / swift-threads / swift-environment / swift-ascii reclassified as L3.2 (unifier-tier utilities, since they're cross-platform composition surfaces) OR L3.1 (if they're platform-policy-tier). Either reclassification resolves the lateral as downward. RESOLVED via re-classification + structural composition. |
| **Pattern 3** swift-windows → swift-systems | swift-windows is L3.1. swift-systems reclassified as L3.2 (domain) — composition L3.1 → L3.2 is upward, FORBIDDEN. Does not resolve Pattern 3 unless swift-systems re-tiers to L3.1 OR L2.5. |

**Cost**: medium-high. Re-classification is a documentation pass per package + Package.swift target-dep validation. The compiler / SPM enforces the dep direction via existing target-dep mechanism. Two findings (P2.11, Pattern 3) only partial-resolve — need pairing with Option C.

**Risk**: structural enforcement is good. The dep direction is type-system-checkable (Package.swift target-deps form a DAG; SPM rejects cycles). Per `feedback_structural_fix_preference.md`, preferred over (A).

### Option C — Re-tier consumed packages downward

Move specific packages downward in the layer stack to eliminate the lateral. Per-package decision; complex but most surgically structural.

**Per-finding cell**:

| Finding | Resolution under (C) |
|---------|----------------------|
| **P2.11** swift-darwin/linux → swift-posix | swift-posix moves to **L2.5** (between L2 spec and L3 platform-policy). Becomes "POSIX-shared L3-policy that platform-policy packages compose downward." swift-darwin / swift-linux composing swift-posix is downward composition; lateral evaporates. RESOLVED. |
| **P2.12** swift-file-system → swift-io/threads/environment/ascii | Per-package re-tier: swift-io → L2.5 (it's IO-strategy unification, foundational); swift-threads → L2.5 (thread synchronization primitives); swift-environment → L2 or L2.5 (env access is largely POSIX/Win32 wrapper); swift-ascii → L2 (it's an ASCII spec implementation per [API-NAME-003], conceptually L2). swift-file-system composing all of these is then downward. RESOLVED via per-package re-tier. |
| **Pattern 3** swift-windows → swift-systems | swift-systems → L2.5 (system-info as platform-shared utility, consumed by all platforms). swift-windows composing swift-systems is downward. RESOLVED. |

**Cost**: medium. Per-package re-classification + Package.swift dep updates + DocC catalog labels updated. Each re-tiered package needs a brief Research note explaining the move (e.g., "swift-posix re-tiered L3 → L2.5 because it provides cross-Darwin/Linux POSIX-policy, which is structurally L2.5 not L3-platform-policy"). The L2.5 tier is itself a new concept — needs codification in [PLAT-ARCH-001].

**Risk**: structural. SPM-enforceable via dep direction. Introduces L2.5 as a new layer, which adds cognitive complexity but (per principal feedback) is preferred over rule-based conventions. Could be staged (one re-tier per cycle).

**Note**: Option C overlaps with Option B in motivation (structural enforcement) but differs in scope: B re-classifies INSIDE L3 (sub-tiering); C re-classifies BETWEEN L3 and L2 (downward moves to L2.5). They could combine: re-tier swift-posix to L2.5 (C-style) AND introduce L3.1/L3.2/L3.3 sub-tiering for the rest (B-style).

### Option D — Restructure to eliminate the lateral

Remove the lateral patterns by changing the decomposition: merge or absorb laterally-composed packages.

**Per-finding cell**:

| Finding | Resolution under (D) |
|---------|----------------------|
| **P2.11** swift-darwin/linux → swift-posix | Merge swift-posix's POSIX-policy into swift-darwin and swift-linux as `Darwin.POSIX.*` and `Linux.POSIX.*` extensions. swift-posix as a separate package goes away. Cross-platform unifier (swift-kernel) composes Darwin and Linux directly. RESOLVED via package elimination. |
| **P2.12** swift-file-system → swift-io/threads/environment/ascii | Refactor swift-file-system to inline the composed pieces (define IO scheduling, thread primitives, environment access internally) — likely impossible without massive scope expansion. OR merge swift-io / swift-threads / etc. into one mega-package alongside swift-file-system. Both are unattractive. NOT RECOMMENDED for P2.12. |
| **Pattern 3** swift-windows → swift-systems | Merge swift-systems into swift-windows / swift-darwin / swift-linux as platform-specific Sytems extensions. Same shape as P2.11's merge, similar cost. RESOLVED. |

**Cost**: very high. Cross-package merges require ecosystem-wide refactor; downstream consumers update; DocC catalogs re-organize. The benefit is that the composition pattern disappears entirely — nothing to enforce because nothing exists.

**Risk**: structural to the extreme. The lateral is ELIMINATED, so the compiler/SPM has nothing to enforce because the offending pattern doesn't exist. But the cost is unjustified for P2.12 specifically; partial-restructure may apply for P2.11 + Pattern 3.

---

## Cross-Option Summary

| Option | P2.11 resolution | P2.12 resolution | Pattern 3 resolution | Cost | Enforcement |
|--------|------------------|------------------|----------------------|:----:|:-----------:|
| A — Codify carve-out | Rule extension | Rule extension | Rule extension OR re-classification | Lowest | Convention |
| B — Explicit sub-tiering | Partial (needs L3.1 sub-split or pair with C) | Re-classification within L3 | Partial (needs C or sub-split) | Medium-high | Structural (SPM dep DAG) |
| C — Re-tier downward | Re-tier swift-posix → L2.5 | Per-package re-tier | Re-tier swift-systems → L2.5 | Medium | Structural (SPM dep DAG) |
| D — Restructure | Merge swift-posix into Darwin+Linux | Not recommended | Merge swift-systems into platforms | Very high | Structural (elimination) |

---

## Discipline Considerations

`/platform`'s [PLAT-ARCH-*] rules trend toward type-system enforcement over textual conventions (matches `feedback_structural_fix_preference.md` auto-memory entry). Each option is rated for enforcement mechanism:

- **(A) Codify carve-out**: convention only. Compiler / SPM does not enforce "only POSIX-shared lateral allowed." Future drift is review-only-caught.
- **(B) Explicit sub-tiering**: structural via Package.swift target-dep declarations. SPM dep DAG enforces the direction; cross-tier violations fail at build time. Sub-tier labels live in DocC catalog + [PLAT-ARCH-001] table. The label-to-dep-direction binding is conventional, but the dep-direction-itself is enforced.
- **(C) Re-tier downward**: structural via Package.swift dep direction (same as B). The L2.5 tier is itself a new label-convention; the dep-direction-itself remains SPM-enforced.
- **(D) Restructure**: most structural — the offending pattern is eliminated. Nothing to enforce.

**Per the structural-preference principle, (B), (C), (D) are preferred over (A).** (A) is the cheapest at write time but the most fragile against future drift.

A hybrid is plausible: codify the sub-tiering explicitly (B's primary contribution), THEN apply (C) per-finding to specific re-tiers where needed. This aligns with the principal's "carve-out-vs-restructure" framing — sub-tiering is the architectural decision; per-package re-tiers are the remediations applied within that decision.

---

## Recommendation

**OPTIONS MATRIX — decision escalates to principal.**

This Doc presents the four options without committing. The principal-stamp moment is on the matrix shape (which option, or which hybrid), not per finding. One stamp closes both P2.11 and P2.12 + the Pattern 3 evidence-instance.

**Suggested principal questions to settle**:

1. **Sub-tier enumeration**: should L3 split into L3.1 / L3.2 / L3.3 (or unifier / platform-policy / domain by name)? This is Option B's primary contribution, and is necessary for any of B, C, or hybrid to land cleanly. Could land as a `[PLAT-ARCH-001a]` extension to the canonical layer table without committing to composition rules yet.
2. **Composition mechanism**: prefer (A) rule-based or (B/C) structure-based? Per the structural-preference principle, the answer is structure-based — but (A) is fastest if the principal accepts the convention-cost.
3. **swift-posix's tier**: Option C re-tiers swift-posix to L2.5 ("POSIX-shared L3-policy"). Is this conceptually correct? swift-posix is structurally between L2 (spec-literal POSIX in swift-iso-9945) and L3-platform-policy (Darwin/Linux/Windows). The re-tier IS conceptually clean; the question is whether the L2.5 tier itself is welcome.
4. **Hybrid B+C tolerance**: combining sub-tiering (B) with per-package re-tiers (C) is the cleanest end-state but adds two architectural moves. Acceptable, or pick one?
5. **Restructure scope (D)**: D is recommended only for narrow patterns (P2.11 swift-posix merge, Pattern 3 swift-systems merge). NOT recommended for P2.12 (too costly). If D applies anywhere, it would be P2.11's swift-posix specifically — but that conflicts with C's swift-posix → L2.5 re-tier. Pick one or the other for P2.11.

**Once the principal stamps the matrix**, remediation cycles dispatch separately per finding: P2.11 cycle (resolves swift-posix's tier), P2.12 cycle (resolves L3-domain composition), Pattern 3 cycle (resolves swift-systems' tier).

---

## Provenance + Cross-References

- **Audit findings**: P2.11, P2.12 in `swift-institute/Audits/platform-compliance-2026-04-21.md` (2026-04-25 dispatch + same-day promotions from META M-01/M-02).
- **Canonical layer doc**: `swift-institute/swift-institute.org/Swift Institute.docc/Layers.md` (current 3-layer table; would extend under Option B).
- **Composition precedent**: [PLAT-ARCH-008e] (`swift-foundations/.claude/skills/platform/SKILL.md`) — the sole codified within-L3 composition rule.
- **Domain authority precedent**: [PLAT-ARCH-008a], [PLAT-ARCH-008d] — frame L3-domain `#if os()` policy without explicitly authorizing peer composition; relevant context.
- **Same-class research**: `file-handle-writeall-l2-l3-layering.md` (2026-04-22, decision-ready options matrix; principal-stamped Option 5). Shape precedent for this Doc.
- **Structural-preference memory**: `feedback_structural_fix_preference.md` — type-system enforcement preferred over conventions; informs Discipline Considerations.
- **Reflection**: `2026-04-25-platform-audit-dispatch-and-same-day-hygiene-arc.md` (this session's reflection captures the deflection-via-META anti-pattern that produced P2.11/P2.12 promotions; this Doc is the resulting design discussion).

---

## Stamped Decision (2026-04-26)

**Selected**: Hybrid B+C — explicit 3-sub-tier enumeration within L3 + per-package classification (no L2.5 introduction; swift-posix stays L3-policy).

**Principal direction (verbatim, paraphrased for record)**: "swift-posix is to iso-9945 what swift-linux is to swift-linux-standard, swift-darwin is to swift-darwin-standard, and swift-windows is to swift-windows-standard. L2 is raw encoding, and the L3 adds policy. Other L3 packages, like swift-kernel, provide unified API across platforms. And further L3 packages should use the unified API. swift-darwin/swift-linux should depend on swift-posix. swift-ascii is the L3 for the L2 INCITS and L1 ASCII primitives. swift-windows for Windows-NUMA implementation."

### Stamped sub-tier enumeration

Three explicit sub-tiers within L3-Foundations:

| Sub-tier | Role | Members |
|----------|------|---------|
| **L3-policy** | Per-spec policy wrappers. Each L3-policy package wraps an L2-spec sibling and adds policy (EINTR retry, partial-IO loop, error normalization, etc.). | swift-posix (wraps iso-9945), swift-darwin (wraps darwin-standard), swift-linux (wraps linux-standard), swift-windows (wraps windows-standard) |
| **L3-unifier** | Cross-platform unification. Provides unified API across platforms; composes L3-policy packages downward per [PLAT-ARCH-008e]. May internally layer (some unifiers compose other unifiers). | swift-kernel (kernel-level base unifier), swift-strings (string handling), swift-paths (path handling), swift-ascii (ASCII spec facade), swift-systems (system info), swift-io (IO event scheduling on top of swift-kernel), swift-threads (thread synchronization on top of swift-kernel), swift-environment (env access on top of swift-kernel) |
| **L3-domain** | Domain-specific composition. Composes L3-unifier downward; SHOULD NOT compose L3-policy directly (must go through unifier). | swift-file-system + future domain packages |

**Empirical anchor**: swift-systems' classification was the principal's "I'm not sure this applies correctly for all these" caveat. Source-level Package.swift inspection confirmed swift-systems composes swift-darwin/swift-linux/swift-windows DIRECTLY (no swift-kernel dep), structurally identical to swift-kernel's [PLAT-ARCH-008e] composition pattern. swift-systems is therefore L3-unifier (peer to swift-kernel, providing system-info unification), NOT L3-domain. swift-io / swift-threads / swift-environment do depend on swift-kernel and provide higher-level cross-platform APIs ON TOP of swift-kernel — they are L3-unifier-feature (a internal sub-layer within L3-unifier).

### Stamped composition matrix

3×3 directional pairs, with status under the stamped decision:

|                                   | → L3-unifier | → L3-policy | → L3-domain |
|-----------------------------------|:------------:|:-----------:|:-----------:|
| **FROM L3-unifier**               | ✓ peer composition allowed (e.g., swift-io composes swift-kernel) | ✓ codified [PLAT-ARCH-008e] | ✗ forbidden (unifiers don't depend on domain) |
| **FROM L3-policy**                | ✗ forbidden (Pattern 3 violation) | ~ ALLOWED for POSIX-shared base extension only ([PLAT-ARCH-008g]) | ✗ forbidden (policy doesn't depend on domain) |
| **FROM L3-domain**                | ✓ canonical (the "use the unified API" rule) | ✗ forbidden (must go through unifier) | (peer composition: TBD if needed; no current instance) |

### Codification candidates (skill amendments)

Two new `[PLAT-ARCH-*]` rules to add to `swift-foundations/.claude/skills/platform/SKILL.md`:

**[PLAT-ARCH-008f] Within-L3 sub-tiering (new ID; or extend [PLAT-ARCH-001])**:
> L3-Foundations is internally sub-tiered into three roles: L3-policy (per-spec policy wrappers), L3-unifier (cross-platform unifiers), L3-domain (domain composition). Composition flows downward from L3-domain through L3-unifier to L3-policy and below. L3-domain MUST compose L3-unifier (not L3-policy directly). L3-unifier MAY compose peer L3-unifier where layering supports it (e.g., swift-io builds on swift-kernel). [PLAT-ARCH-008e] codifies the L3-unifier → L3-policy direction.

**[PLAT-ARCH-008g] L3-policy peer composition for POSIX-shared base (new ID)**:
> swift-posix is the POSIX-shared L3-policy base. swift-darwin and swift-linux MAY compose swift-posix as their POSIX subset's policy provider; this is the only sanctioned L3-policy peer composition pattern. swift-windows is non-POSIX and MUST NOT compose swift-posix. Other L3-policy peer compositions (e.g., swift-darwin → swift-linux) remain FORBIDDEN.

### Per-finding resolutions

**P2.11** (swift-darwin/linux → swift-posix lateral) → **RESOLVED-via-codification**:
- The principal direction "swift-darwin/swift-linux should depend on swift-posix" explicitly authorizes this composition.
- Codify as `[PLAT-ARCH-008g]` (or principal-chosen ID) in the platform skill.
- Status update: P2.11 marked RESOLVED in synthesis tracker once the rule lands.
- No code change; per-package audit.md row text updates locally.

**P2.12** (swift-file-system → swift-io/threads/environment/ascii) → **RESOLVED-via-classification**:
- swift-io / swift-threads / swift-environment / swift-ascii are all L3-unifier (cross-platform unification surfaces), NOT L3-domain peers.
- swift-file-system → L3-unifier is canonical L3-domain composition (covered by [PLAT-ARCH-008f]'s "L3-domain MUST compose L3-unifier" clause).
- Status update: P2.12 marked RESOLVED in synthesis tracker once [PLAT-ARCH-008f] lands.
- No code change; classification is via skill text + DocC catalog updates.

**Pattern 3** (swift-windows → swift-systems via `Windows.Thread.Affinity.swift:16`) → **NEW FINDING — refactor required**:
- swift-windows is L3-policy; swift-systems is L3-unifier; FROM L3-policy → TO L3-unifier is UPWARD = forbidden under [PLAT-ARCH-008f].
- Refactor: remove `import Systems` from `swift-windows/Sources/Windows Kernel/Windows.Thread.Affinity.swift`. The `applyCores` method takes a list of CPU cores; the caller (in swift-systems' Windows-NUMA implementation, or in user code) resolves topology via swift-systems and passes cores. swift-windows applies the mask without needing topology resolution.
- This makes the dependency direction structurally correct: swift-systems → swift-windows for Windows-NUMA implementation (canonical L3-unifier → L3-policy per [PLAT-ARCH-008e]).
- New finding ID: **P3.5** (or principal-chosen). Severity: MEDIUM (single-file refactor; behavior preserved when caller threads topology through). Effort: S–M.

### Out-of-scope confirmations

- swift-paths Test target composing swift-kernel: TEST-SCOPE LAXER. Test target dep doesn't enter the L3-domain → L3-unifier rule. Confirmed not a finding.
- L3-unifier internal layering (swift-io builds on swift-kernel; swift-threads builds on swift-kernel; etc.): permitted under "[PLAT-ARCH-008f]'s L3-unifier MAY compose peer L3-unifier where layering supports it" sub-clause. Documented in the rule's sub-clause; no per-package finding.

### Remediation cycle dispatch order

1. **Skill amendment cycle** (~1 session): land [PLAT-ARCH-008f] + [PLAT-ARCH-008g] in `swift-foundations/.claude/skills/platform/SKILL.md`. Closes P2.11 + P2.12 in synthesis tracker.
2. **Pattern 3 refactor cycle** (~1 session): swift-windows.Thread.Affinity refactor + caller-thread-topology. Adds P3.5 finding to tracker; immediately resolves it via the same dispatch.
3. **Per-package audit.md hygiene sweep** (~1 session): walk all 13 audit packages; update per-package audit.md row text to reflect the stamped sub-tier classification + flagged composition rules. Anchor case (swift-kernel L3 Composition #1/#2 stale-RESOLVED) addressed in this sweep.

Three cycles total to close out P2.11 + P2.12 + Pattern 3 + per-package staleness hygiene. None require Windows CI (refactor in #2 is macOS-syntax-verifiable since the file is `#if os(Windows)`-guarded).
