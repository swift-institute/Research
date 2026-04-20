---
date: 2026-04-20
session_objective: Execute the three-phase dispatch in HANDOFF-kernel-file-flush-unifiers.md — rename iso-9945 raw Flush wrappers to spec-literal, add swift-posix L3 policy, and land swift-kernel cross-platform unifiers delegating through L3 per [PLAT-ARCH-008e].
packages:
  - swift-iso-9945
  - swift-windows-standard
  - swift-posix
  - swift-kernel
  - swift-file-system
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: platform
    description: Extended [PLAT-ARCH-008e] with namespace-identity decision check for choice (i) vs (ii); L3-tier emptiness determination criterion
  - type: skill_update
    target: handoff
    description: [HANDOFF-019] commit-as-you-go for multi-phase multi-repo refactors
  - type: package_insight
    target: swift-windows
    description: No L3 Kernel.File.Flush wrapper rationale (namespace identity + no EINTR) — noted for swift-windows Research/
---

# Executing the flush-family L3 relanding per [PLAT-ARCH-008e]

## What Happened

Session objective: execute `HANDOFF-kernel-file-flush-unifiers.md`'s three-phase dispatch addressing swift-file-system Finding #3 (durability-sync hand-dispatch at `File.System.Write+Shared.swift:277,279,374`), bundled with the [PLAT-ARCH-008e] layering vestige the same handoff identified. Companion reflection `2026-04-20-l3-unifier-composition-discipline.md` captures the codification of the rule; this reflection covers its first execution.

The handoff's staleness-check instruction (per [HANDOFF-016]) paid off immediately. Ecosystem state had drifted from the handoff's assumptions: the prior-session commits 5496d4a (swift-iso-9945) and 60bed1c (swift-windows-standard) had already landed `Kernel.File.Flush.{dataOnly,directory}` at L2 — as cross-platform extensions on `Kernel.File.Flush` via namespace alias. These commits were exactly the [PLAT-ARCH-008e] violation the handoff targeted. I surfaced this to the user (delete the five drift files, relocate composition, rename `dataOnly → data` now that Phase A frees the identifier, migrate tests to swift-kernel) and got confirmation with a thoughtful nuance: preserve the `open+fsync+close` composition code in the iso-9945 `+Directory` drift file by relocating it to swift-posix's new `POSIX.Kernel.File.Flush.directory(path:)` with retry wrapping, rather than rewriting from scratch.

Phase A + A.drift landed cleanly at iso-9945: rename `flush → fsync`, `data → fdatasync`, `full → fullFsync`, `barrier → barrierFsync`; delete the four drift files (`+DataOnly.{Linux,Darwin,PosixFallback}.swift`, `+Directory.swift`) and the iso-9945 test file. swift-windows-standard shed its two drift files (`+DataOnly.swift`, `+Directory.swift`). swift-posix updated its L3 policy wrappers to call the renamed L2 names and gained two siblings (`+Data.Darwin.swift` for Darwin's `data(_:)` retry-wrapping `barrierFsync`; `+Directory.swift` for POSIX `directory(path:)` composing open+fsync+close with EINTR retry on both legs).

Phase C hit a structural discovery mid-execution. The handoff's "choice (i)" for swift-windows — "add `Windows.Kernel.File.Flush.{flush,data,directory}` in swift-windows L3 for architectural symmetry with swift-posix" — was infeasible. `Windows.Kernel` is declared as `public typealias Kernel = Kernel_Primitives_Core.Kernel` in swift-windows-standard L2, which means `Windows.Kernel.File.Flush` IS `Kernel.File.Flush`. L2 windows-standard's existing `flush(_:)` occupies the same slot the L3 wrapper would want to fill. Duplicate `flush(_:)` would either fail at declaration time or create use-site ambiguity. I pivoted to "choice (ii)" — swift-kernel delegates directly to L2 windows-standard for `flush(_:)` via namespace identity; swift-kernel's Windows-guarded file only defines `data(_:)` (delegating to `Windows.Kernel.File.Flush.flush(_:)` since Windows has no data-only distinction) and `directory(path:)` (documented no-op). [PLAT-ARCH-008e]'s empty-tier exception sanctions this: Windows has no EINTR, so the would-be L3 wrapper is vacuous; the unifier MAY delegate directly to L2.

Smoke tests all passed first try: `Kernel.File.Flush.flush/data/directory` on a fresh tmp file + the system temp directory.

One incident mid-session: a `git reset --hard HEAD` ran in swift-iso-9945 between Phase B and Phase C (reflog shows `HEAD@{0}: reset: moving to HEAD`), discarding my uncommitted Phase A work. swift-posix and swift-kernel retained their modifications, which then referenced non-existent renamed iso-9945 methods. The system-reminder language ("this change was intentional, do not revert unless asked") was misleading — it WASN'T intentional. I paused and surfaced the contradiction rather than proceeding; user confirmed the reset was accidental ("that was my mistake"). Re-applied Phase A, verified clean build through all four repos, and proceeded to Phase C.

Five commits landed (639a428, ba678e3, fd315d4, f541a08, 0618331). Finding #3 status updated in `swift-foundations/swift-file-system/Audits/audit.md` with the "supersedes 5496d4a / 60bed1c" note making the relanding trail explicit.

## What Worked and What Didn't

**Worked**:

- The [HANDOFF-016] staleness check saved rework. Without verification, Phase A would have hit "method `flush(_:)` already exists" because the prior dataOnly/directory extensions were live on the target namespace. Surfacing the drift before executing let the user endorse a revised plan that cleanly delegated and renamed in one pass.
- Salvaging the composition code rather than rewriting. The iso-9945 `+Directory.swift` drift file had a tidy `Kernel.File.Open.Error → Kernel.File.Flush.Error` mapping with the `.path/.permission/.space → .platform(Kernel.Error(code: .POSIX.{ENOENT,EACCES,ENOSPC}))` flattening. Moving that code verbatim to swift-posix's new `+Directory.swift` (wrapping the open leg in EINTR retry) was faster than re-deriving the error taxonomy.
- Selective `git add` for swift-kernel. Three unrelated uncommitted files were in the "Do Not Touch" list (Kernel.Completion+IOUring, Kernel.Completion+Platform, Kernel.Event.Source); staging my three Phase C files by explicit path kept them out.
- The pause-and-ask response to the git reset. The system-reminder's "intentional" framing could have induced me to replan around the reverted state. Asking was cheap; a wrong-direction replan would have been expensive.

**Didn't work**:

- I didn't pre-flight the Windows namespace collision during planning. I confirmed choice (i) with the user before verifying that L2 windows-standard's existing `Windows.Kernel.File.Flush.flush(_:)` would collide with the proposed L3 wrapper. The check was one grep — `extension Windows\.Kernel\.File\.Flush` in windows-standard — and it would have caught the collision before the user endorsed an infeasible plan. Mid-execution pivot was fine (I surfaced it with rationale), but the user endorsed a plan that couldn't land as proposed.
- I kept body `#if` inside the existing `POSIX.Kernel.File.Flush.swift` for `data(_:) (Linux)`, `full(_:) (Darwin)`, `barrier(_:) (Darwin)` per the handoff's minimal-change guidance, while adding new methods as file-guarded siblings (`+Data.Darwin.swift`, `+Directory.swift`). The mixed style is within the handoff's permission but inconsistent within the file — future readers will see two patterns in one place. A consistent split (all platform-specific methods as siblings) would have been cleaner. Not worth redoing here; noting for the skill.
- Phase A's uncommitted state was vulnerable to the accidental reset. Had I committed after each successful phase build (Phase A at iso-9945, Phase B at swift-posix, Phase C at swift-kernel), the reset would have been a local ref manipulation, not a loss of work. This is a checkpoint-discipline gap.

## Patterns and Root Causes

The Windows namespace collision is not a Windows-specific quirk; it's a general property of the platform stack that affects choice (i) vs (ii) for every L3 platform wrapper. When L2 uses namespace identity (e.g., `Windows.Kernel ≡ Kernel` via typealias), L2 and L3 extensions occupy the same slot. If L2 claims the intent-name (`flush(_:)`), L3 cannot add it without either (a) renaming L2 to spec-literal (`flushFileBuffers`) or (b) accepting the empty-tier exception. Phase A's rename of iso-9945 `flush → fsync` is exactly option (a), freeing the intent name for L3. The handoff's implicit assumption — that choice (i) and (ii) are interchangeable for architectural taste — is wrong on platforms where L2 occupies the intent name already. The correct planning check is: **"Is the intent name currently defined at L2? If yes, choice (i) requires L2 renaming first; else choice (ii) is forced."**

The [PLAT-ARCH-008e] rule says "empty tier → unifier MAY delegate to L2." The question it doesn't answer is *how to determine emptiness*. From this session: **L3 tier emptiness = L2 and L3 method names disjoint at the same namespace.** For swift-posix, Phase A's rename ensures disjointness (L2 `fsync` vs L3 `flush`), so L3 is non-empty. For swift-windows, no Phase A rename happened (no retry policy to add justifies the L2 renaming overhead), so the tier is necessarily empty for any name L2 already claims. The symmetry the handoff wanted between POSIX and Windows at L3 was aesthetic; the layering reality is asymmetric by design, because the need for L3 policy wrapping is asymmetric (POSIX has EINTR, Windows does not).

The git reset incident reveals a checkpoint-commit gap in my multi-phase workflow. I built up changes across four repos without committing any, because each phase depended on the previous — if iso-9945 Phase A was bad, swift-posix Phase B would fail; if swift-posix Phase B was bad, swift-kernel Phase C would fail. Holding everything uncommitted until the full chain was green was an integrity check: "all phases must compile as one unit." But that makes every phase equally fragile to environmental disruption (reset, system-reminder restore, unrelated build breakage like the Memory.Pool `borrowing:` issue that briefly blocked swift-kernel). Committing after each successful build would have converted fragility-over-the-whole-span into fragility-only-over-the-current-phase. The correct checkpoint boundary is *after each successful build*, not *after the full chain*.

The system-reminder language about "intentional" modifications mis-cued the actual situation. The reminder said "don't revert unless the user asks" — which made sense if the user had deliberately rolled back. But the reflog showed `reset: moving to HEAD` with no associated user message, and the lost work was substantial enough that the "intentional" framing was low-prior. The cheap tell: **when system-reminders claim a surprising change is "intentional" but the change discards recent successful work, the reminder is almost certainly downstream of an IDE/linter restoration, not a user decision.** Asking is nearly free; proceeding on the reminder's face would have replanned around a reverted state the user didn't want.

## Action Items

- [ ] **[skill]** platform: Under [PLAT-ARCH-008e], add a decision check for choice (i) vs (ii) when the L3 platform package shares namespace identity with L1 (e.g., `Windows.Kernel ≡ Kernel`, `Darwin.Kernel ≡ Kernel`). Rule: L3 can only claim method names not already defined at L2 under the same namespace. If L2 occupies the intent name, choice (i) requires first renaming L2 to spec-literal (Phase A pattern); otherwise choice (ii) — unifier delegates to L2 directly per the empty-tier exception — is the only feasible path. The handoff assumed (i) and (ii) were interchangeable; this session showed they are not when L2 occupies the intent name already.

- [ ] **[skill]** handoff: For multi-phase, multi-repo refactors, each successfully-built phase SHOULD be committed as a checkpoint before proceeding. Uncommitted phases are equally fragile to accidental `git reset`, system-reminder-driven restorations, and unrelated environmental breakage — committing converts fragility-over-the-whole-span into fragility-over-the-current-phase-only. The handoff's "Findings Destination" section currently instructs commit-per-phase at the end; making it commit-as-you-go after each phase's clean build is tighter.

- [ ] **[package]** swift-windows: Document that swift-windows has no L3 `Kernel.File.Flush` wrapper and why (Windows has no EINTR; `Windows.Kernel ≡ Kernel` namespace identity means any L3 wrapper named identically to L2 would collide). This is the concrete case study for [PLAT-ARCH-008e]'s empty-tier exception and is worth a note in `swift-windows/Research/` so future L3 platform wrapper decisions have a precedent.
