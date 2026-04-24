---
date: 2026-04-20
session_objective: Pick up HANDOFF-platform-compliance-consumer-migration.md and execute its six migration classes closing two audits
packages:
  - swift-file-system
  - swift-kernel
  - swift-iso-9945
  - swift-posix
  - swift-institute/Skills/platform
  - swift-institute/Skills/handoff
status: processed
processed_date: 2026-04-24
triage_outcomes: see reflections-processing run 2026-04-24
---

# Consumer migration pickup reveals L3 unifier name-parity collision on POSIX-literal syscalls

## What Happened

Picked up `HANDOFF-platform-compliance-consumer-migration.md` (the "terminal" handoff closing both the swift-file-system Platform Compliance audit and the swift-kernel L3 Composition audit). User instruction: `/effort max`, load `/platform` first, do the six migration classes.

Loaded the `platform` skill. Read the handoff in full. Verified ecosystem state across swift-kernel, swift-file-system, swift-iso-9945, swift-posix, swift-primitives via parallel `git log` / audit.md reads. Discovered that the handoff's "Status (reflected 2026-04-20)" block at the top was partially stale:
- Findings #4 (path helpers) and #5 (Random.fill) were listed as "still blocked", but both had already landed at `41e1458` / `228b2b4` / `719468f`.
- Retry-wrapper bundle (Findings #10–#16) had landed at `bfa092e` / `6a6d527` / `5bd87f3` / `5b0ae3b` / `24cf586`.
- Connect (Finding #17) had landed at `6741b6a`.
- Classes 2, 3, 6 consumer migration remained pending. Class 1 also pending.

Observed active parallel-session activity: between two of my own `git status` checks 2 minutes apart, swift-file-system's branch went from 8 to 10 commits ahead of origin — parent committed `8f19d65` (Write-error typed-path upgrade) and `f098a44` (Finding #4 audit status) during my investigation. Staged files I had seen disappeared (committed away).

Executed Class 1 (error-code predicates, 17 sites across 7 files in `Sources/File System Core/`): replaced each `#if os(Windows) ... ERROR_X || ERROR_Y #else POSIX.E* #endif` ladder with calls to the new `Kernel.Error.Code` semantic predicates (`code.isNotFound`, `.isPermissionDenied`, `.isReadOnly`, `.isNoSpace`, and the Parent.Check `.accessDenied`/`.notDirectory`/`.invalidPath`/`.networkPathNotFound` mapping). Files: Permissions, Ownership, Delete, Link.Read.Target, Write.Streaming.Error, Write.Atomic.Error, Parent.Check. The Parent.Check migration collapsed a large Windows-vs-POSIX switch block into a single predicate-based if/else ladder; left the unused `Operation.getFileAttributes` enum case in place (public API, separate cleanup).

Attempted `swift build` to validate Class 1 before committing. Build failed — not on my edits, but on a pre-existing ambiguity in `Kernel.IO.Read.read` / `Kernel.IO.Write.write` / `.pread` / `.pwrite` / `.writeAll`. Root cause: `ISO_9945.Kernel` is a typealias of `Kernel_Primitives.Kernel`, so iso-9945's `extension ISO_9945.Kernel.IO.Write` lands methods on the same type that swift-kernel's new L3 cross-platform unifier extends (commits `24cf586` / `5b0ae3b`). Both declare `write(_:from:)` with identical signatures; Swift's name lookup cannot disambiguate. Errors surface in `File.Handle.swift`, `File.System.Write+Shared.swift`, `swift-kernel/Tests/Support/*`, `swift-posix/Sources/POSIX Kernel File/*`, `swift-kernel/Sources/Kernel Completion/*` — broad, ecosystem-wide.

Paused editing, reported state to user. Parent then committed `93e3a50 "Save progress: 2026-04-20"` which bundled my uncommitted Class 1 edits with their own typed-path upgrade + test-file naming migration + new `File.System.IO.*` integration files. The per-class bisect granularity the original handoff specified was lost.

User subsequently informed me they had attempted an `@_spi(Syscall)` fix on iso-9945's L2 methods and reverted it (incompatible with swift-posix's `@inlinable` L3 wrappers; too many downstream callers relied on the transitive re-export). They authored `HANDOFF-io-read-write-l2-l3-ambiguity.md` recommending Option A: a `Raw` sub-namespace on L2 (`Kernel.IO.Write.Raw.write`). Asked me to review and add to it.

Made four surgical additions to that handoff: corrected finding numbers (`#14–16` → `#5–9`; #14–16 is Socket.Receive, a different family); corrected Write+Shared.swift line numbers (`:101,:152` → `:99,:150` with clarification that these are inline `Kernel.IO.Write.write` calls inside custom partial-write loops, not a literal `writeAll`); sharpened the Write+Shared.swift migration recommendation (L3 unifier over `.Raw.*` — the outer loop already handles partial writes, and delegating EINTR retry to L3 is a semantic improvement that fixes an incidental bug where EINTR was currently surfaced to the outer loop as a non-retried `Kernel.IO.Write.Error`); added a Parent Context cross-reference to the original consumer migration handoff, clarifying that Class 1 already landed independently (93e3a50) and Classes 2/3/6 are blocked for test validation only, not for symbol resolution.

## What Worked and What Didn't

**Worked**:
- Loading `/platform` before starting, per the handoff's explicit instruction. The subsequent [PLAT-ARCH-008e] analysis required it.
- Parallel verification of upstream state in a single tool batch: `git log` + `git status` across 4 repos + audit ledger reads + predicate-file greps. Surfaced the staleness of the handoff's blocker list in one round-trip.
- Fact-checking the new handoff before adding to it. Fresh greps against current code caught two factual errors (finding numbers, line numbers) that would have misled the next agent. This validates `[feedback_verify_prior_findings.md]` applied to handoffs, not just code.
- Class 1 edits themselves were correct — they landed in `93e3a50` and the migration pattern collapses ~80 lines of conditional-code duplication to ~15 lines of predicate calls. When the IO ambiguity fix lands, Class 1 will validate.
- Treating the active parallel-session activity as a signal to pause rather than power through. Auto mode's "minimize interruptions" tempted further editing; "do not take overly destructive actions" correctly dominated given the parent was mid-refactor on the foundation layer.

**Didn't work**:
- Started Class 1 edits before running `swift build` to validate the baseline. A build-first step would have surfaced the pre-existing ambiguity immediately and reframed the session from "do 6 classes" to "flag upstream bug, unblock, then do 6 classes". Wasted effort on edits I could not validate.
- Trusted the handoff's "Status (reflected 2026-04-20)" block at first. That block was a snapshot-at-authoring; in a workspace where the user committed every few minutes, it had drifted by hours. Re-verification was buried in my investigation rather than being the first step.
- Did not consider `isolation: "worktree"` when dispatching edits. A worktree would have kept my uncommitted edits out of the parent's `git add .` path — preserving the per-class bisect discipline the handoff specified. The parent's `Save progress` commit absorbed them as a side effect of working in the same directory tree.
- The handoff gap itself: a terminal consumer migration handoff that assumes upstream is complete is fragile to mid-cycle upstream breakage. The handoff had "If any upstream dependency is missing or differs, flag" — but the breakage I hit was not "missing"; it was "landed-but-broken" (the retry-wrapper bundle landed and introduced the collision). A stronger phrasing would be "if the upstream landing introduces a new blocker, flag".

## Patterns and Root Causes

**Pattern 1: [PLAT-ARCH-008e] naming-parity collides structurally when POSIX spec-literal = abstract domain name.**

The rule as written says the L3 unifier composes over the L3 platform-policy tier (swift-posix), using the same method name to preserve naming parity. For the Flush family, the L2 raw names and L3 abstract names diverge by design (`fsync`/`fdatasync`/`fullFsync`/`barrierFsync` at L2; `flush`/`data`/`directory` at L3). No collision.

For IO.Read and IO.Write, the POSIX man-page names literally *are* the abstract-domain names: `read`, `write`, `pread`, `pwrite`. The L2 method sits at `ISO_9945.Kernel.IO.Read.read`; namespace alias routes that to `Kernel.IO.Read.read`; the L3 unifier also declares `Kernel.IO.Read.read`. Identical signature, identical visibility — compile error at every downstream call site.

This is not a bug in commits `24cf586` / `5b0ae3b`. The unifiers themselves are correct per the rule. The bug is that the rule doesn't account for the case where POSIX names don't naturally disambiguate. Flush sidestepped this *accidentally* (POSIX's authors picked names distinct from the abstract concept). Socket syscalls sidestepped it *deliberately* — the parent's `2c63378 "remove socket unifier files (migrating to swift-sockets)"` moved the L3 unifier OUT of swift-kernel into swift-sockets, placing it in a different module where the L2 namespace alias doesn't flow through. That's a package-level disambiguator.

The prescribed fix (Option A — `Kernel.IO.Write.Raw.write`) is a type-level disambiguator. Both work; both belong to a family of solutions the rule currently doesn't enumerate.

The generalization: whenever an L3 unifier's method name is identical to the POSIX man-page name on the L2 raw surface, a disambiguator MUST land in the same commit as the unifier. Options are (a) rename L2 to a spec-literal that differs from the abstract name (Flush precedent); (b) rename L3 abstract to differ from POSIX (defeats the point of parity); (c) introduce a sub-namespace on L2 (`Raw`) or on L3 (less common); (d) house the L3 unifier in a different package than the L2 re-exporter (socket precedent).

**Pattern 2: handoff status blocks are perishable in multi-session workspaces.**

The "STATUS (reflected YYYY-MM-DD)" block at the top of a long-lived handoff is a snapshot of the authoring moment. In a workspace where the user (or a parallel agent) is actively committing, the block's blocker list drifts in hours, not days. The handoff I picked up said "Do not start until ALL upstream handoffs have landed" and listed specific landings as missing — but by the time I checked, several had landed.

`[feedback_verify_prior_findings.md]` already applies this principle to code. The recurrence here suggests the rule should generalize: any claim a handoff makes about the state of the world should be re-verified at dispatch, not trusted. The blocker list at the top of a handoff is a claim about the state of upstream repos — subject to the same verification requirement.

**Pattern 3: uncommitted work is a shared resource across parallel sessions in the same working tree.**

I made Class 1 edits intending to stage them as 6 separate commits per the handoff's bisect-friendly structure. The parent's `git add .` in another session (or their own shell) absorbed my uncommitted edits into their `Save progress` omnibus commit. Not malicious; not unusual — just a natural consequence of two sessions editing the same working tree.

The user's in-session comment "I don't care too much about git history at this time" acknowledges this working mode: velocity > bisect granularity when the overall work is exploratory. But a handoff that specifies "six classes as six commits" assumes a coordinated-commit workflow that bundled-save-progress breaks.

Mitigations: (a) `isolation: "worktree"` for handoff dispatches that require commit discipline; (b) handoffs state the expected workflow explicitly ("commit per class" vs "bundle-into-save-progress-is-fine"); (c) next-session agent checks git state every few minutes to detect bundling in time to re-stage their own changes.

## Action Items

- [ ] **[skill]** platform: Extend [PLAT-ARCH-008e] with a naming-parity-collision pre-check. When landing an L3 unifier method whose name is identical to the POSIX man-page name on the L2 raw surface (via the `Kernel_Primitives.Kernel` namespace alias), a disambiguator MUST land in the same commit. Enumerate the four solution families: (a) L2 spec-literal rename (Flush precedent), (b) L3 abstract rename, (c) sub-namespace on L2 (`Raw`, IO.Read/Write Option A), (d) package-level separation (socket precedent). Without this, the L3 unifier silently introduces ecosystem-wide compile breakage the moment it lands.

- [ ] **[skill]** handoff: Add a dispatch-time re-verification requirement. Any handoff with a "Status (reflected YYYY-MM-DD)" block listing upstream blockers, open findings, or test baselines MUST be re-verified at pickup, not trusted. The re-verification is cheap (`git log` + audit-ledger reads) and catches the common failure where the handoff was authored hours before pickup in a workspace with active parallel commits. Update the status block in-place before starting work.

- [ ] **[research]** Parallel-session coordination for handoff pickups with commit-discipline requirements. The `Agent` tool's `isolation: "worktree"` option exists but is not the default. When a handoff specifies "N classes as N commits" and the user is making bundled-save-progress commits in the same working tree, the bisect discipline the handoff intends is structurally incompatible with the workspace's actual working mode. Document or decide: is worktree isolation the right default for commit-disciplined handoffs, or should handoffs adapt their expectations to bundling?
