---
date: 2026-06-04
session_objective: Collapse Span.Borrowed.Protocol into a single Span.Protocol (msb follow-up #1 + folded #12b), worktree-isolated, then merge + post-merge empirical close under supervisor GO
packages:
  - swift-span-primitives
  - swift-storage-primitives
  - swift-memory-cursor-primitives
  - swift-memory-iterator-primitives
  - swift-binary-parser-primitives
  - swift-ascii
status: processed
processed_date: 2026-07-02
triage_outcomes:
  - type: no_action
    description: "[PKG-BUILD-013] cold-build/Package.resolved/pin-assert proposal: already landed — the rule exists verbatim (added 2026-06-04 from the sibling W3-endgame reflection; swift-package-build SKILL.md:409). Duplicate."
  - type: skill_update
    target: handoff
    description: "Proposal collected (recommend KEEP, fold into the [HANDOFF-035]/merge-back family): in worktree arcs with merge-excluded scaffolding commits, scaffolding and mergeable edits MUST live in disjoint files OR merge-readiness MUST assert excluded commits carry zero mergeable hunks (binary-parser Package.swift comment-repoint swallow, completed post-merge as 85e47bd1)."
---

# Span.Protocol Collapse (Unify Arc): One Capability, Both Lifetime Regimes — and Three Tool-Reach Failures in One Session

## What Happened

Executed `HANDOFF-span-protocol-collapse.md` end-to-end as session "Unify": collapsed
`Span.Borrowed.Protocol` (`@_lifetime(copy self)` borrowed leg) into a single
`Span.Protocol` (`~Copyable, ~Escapable`, `@_lifetime(borrow self)` — the receipt-proven
unique unifier), plus the folded #12b pair (`Storage.Heap: Span.Mutable.Protocol {}` empty
conformance; `@_lifetime(&self)` on the Mutable requirement) as separate commits.

Key sequence: at-collapse-time enumeration ([HANDOFF-050]/[HANDOFF-040] forms) found the
conformer set DIVERGED from the handoff's expectation — Path.Borrowed ×2 and
String.Borrowed never conformed on the pushed mains (nothing to repoint); `String` already
conformed owned `Span.Protocol`. The step-0 `/tmp` probe refuted the anticipated
`where Base: Escapable` cascade entirely: generic parameters keep their implicit
`Escapable` default under a `~Escapable`-suppressed protocol, so every by-value cursor
site (Memory.Cursor, Binary.Cursor/Reader) compiled unchanged — collapse-plan step 3 was a
no-op. The memory-iterator owned/borrowed Iterable bridges (identical bodies, differing
only in restated `~Escapable`) merged into ONE extension — the collapse's thesis made
concrete. 21 worktrees under `.span-wt/` (W3 Finding-7 path-dep wiring; root path-deps
override transitive url identities — confirmed empirically); the principal live-revised
the verification scope mid-arc (velocity trim: sweep cut at 5/16, 3 genuinely-unverified
packages run directly, 7 deduced-from-transitive-compilation).

Supervisor verification REFUTED one claim: "termination greps clean incl. DocC-slash" —
the origin package's own `.docc` catalog still documented the three-protocol lattice as
current ([AUDIT-036] minted from this). Fixed (`459c71a`), then under the principal's
MERGE YES: 11 repos landed (span ff ×4; 10 cherry-picks), zero conflicts. The final grep
caught binary-parser's Package.swift comment repoints mis-bundled into the merge-EXCLUDED
DEV-ONLY wiring commit ([SUPER-052] catch; completed on main as `85e47bd1`). Post-merge
empirical close v1 was entirely TAINTED: stale untracked `Package.resolved` lockfiles
survived `rm -rf .build` and pinned PRE-MERGE revisions (span at the W1 base!) — my
PIN-ASSERT flagged every mismatch; v2 (+ lockfile removal) ran **21/21 GREEN | PIN-OK,
2,155 cold tests** (deduced-seven converted to empirical, zero borrow-scoping casualties),
GATE-MAIN `witness_method=0`. Worktrees retired (clean-asserted), receipt banked to
`.probe-bank/`, [SUPER-011] termination SUCCESS, seat-accepted.

**Would-be push set (durable record; principal's push window)** — 10 repos / 13 commits:
swift-span-primitives `f2c0c4f`,`f32df96`,`bee5967`,`459c71a` · swift-storage-primitives
`9e01f16` · swift-memory-cursor-primitives `cd36b13` · swift-memory-iterator-primitives
`81597a2` · swift-binary-parser-primitives `6e904662`,`85e47bd1` · swift-binary-primitives
`873537b` · swift-memory-primitives `b484777` · swift-byte-parser-primitives `4204c67` ·
swift-lexer-primitives `a19db68` · swift-ascii `2177931`. (swift-byte-primitives `b03dbd9`
already reached origin via a parallel session's push.) Interleaved Sweep commits sharing
the window: `94823a8`, `3ec5c21`, `5b2a290`, `387bf57`.

**HANDOFF scan ([REFL-009])**: 39 handoff files at `~/Developer/.handoffs/`; **1 consumed
→ soft-deleted to `.trash/`** (`HANDOFF-span-protocol-collapse.md` — arc complete, all
ground rules verified, seat-stamped SUCCESS; push set preserved above); **38
out-of-authority no-touch** (active msb-tower program ledgers incl.
`HANDOFF-msb-tower-followups.md`, whose item #12b this arc CONSUMED — flagged here, not
annotated, per [REFL-009a] in-flight conservativism; `HANDOFF-storage-memory-split.md` =
Cleave in-flight; remainder out-of-session-scope). No `/audit` invoked → no finding
updates.

## What Worked and What Didn't

**Worked**: probe-first sizing (the one un-spiked piece answered in minutes, killing a
feared ecosystem-wide `where Base: Escapable` cascade); PIN-ASSERT as a first-class sweep
column (it converted silent verification taint into loud, attributable failure); the
worktree dirty-check before retirement catching binary-parser's never-committed source
repoints; per-event Monitor streaming on the long sweep (the principal asked for
intermittent visibility — the first interim check immediately exposed the lockfile taint,
saving a 45-minute wait for garbage); honest-record corrections (the refuted grep claim
annotated, not papered over).

**Didn't**: my termination grep's scope was narrower than its claim on TWO axes (file
types `*.swift`-only; consumer-packages-only — missing the origin's `.docc`); `swift build
| tail` pipeline masked a build failure behind `tail`'s exit 0 (background task reported
success on a failed build); bundling same-file scaffolding and substance (binary-parser
Package.swift wiring + comment repoints in one staged file) let the merge-excluded commit
swallow mergeable hunks; v1 cold-build discipline treated `rm -rf .build` as "cold" while
`Package.resolved` silently pinned the pre-merge world.

## Patterns and Root Causes

**One failure class, three instances: verification-tool reach ≠ claim scope** (the
[REFL-011] tool-reach extension, hit thrice in a single session). (1) grep with
`--include="*.swift"` + consumer-package paths read as "no stale references anywhere" —
but `.docc` markdown and the origin package were outside the tool's reach. (2) `rm -rf
.build` read as "cold resolution" — but the lockfile (`Package.resolved`) is resolution
state living OUTSIDE `.build`'s reach, and it pinned pre-merge revisions while every
build reported green. (3) `cmd | tail -2` read as "command succeeded" — but the pipeline's
exit code is `tail`'s, not the build's. In each case the green/clean/zero output was
true OF THE TOOL'S REACH and false of the claim. The fix was identical each time: align
reach with claim (add file types + origin paths; delete the lockfile + PIN-ASSERT pins
against dep HEADs; check `PIPESTATUS[0]` or run unpiped). PIN-ASSERT deserves emphasis
as the structural antidote: it asserts the *world-state the verification claims to be
about*, independent of any tool's success signal.

**Scaffolding and substance must not share files.** The DEV-ONLY wiring commits
(merge-excluded by design, per the W3 merge-back model) were safe exactly until a
substantive edit landed in the SAME file (Package.swift comments) — then exclusion
swallowed substance. The defect was invisible to per-worktree build+test (comments) and
surfaced only at the final on-main grep. Either keep merge-excluded edits in disjoint
files from mergeable edits, or assert before reporting merge-readiness that excluded
commits contain zero mergeable hunks.

**At-collapse-time enumeration vindicated premise-staleness discipline twice**: the
handoff's expected conformer set (Path/String.Borrowed) was wrong about the pushed mains,
and the workspace had grown a new parallel zone (`.split-wt`) the handoff's exclusion
list didn't name. Enumeration-at-execution-time ([HANDOFF-016]/[HANDOFF-021]) is what
made both harmless.

## Action Items

- [ ] **[skill]** swift-package-build: extend the [PKG-BUILD-013] clean-room/pin-assert family — "cold build" discipline MUST remove the untracked `Package.resolved` lockfile alongside `.build` AND pin-assert resolved revisions against dep main HEADs; cite the 2026-06-04 v1 post-merge sweep taint (lockfiles pinned pre-merge revisions; PIN-ASSERT caught it).
- [ ] **[skill]** handoff: amend the [HANDOFF-035]/merge-back family — in worktree source-delta arcs with merge-excluded scaffolding commits (DEV-ONLY wiring), scaffolding and mergeable edits MUST live in disjoint files, OR merge-readiness MUST assert excluded commits carry zero mergeable hunks ([SUPER-052] catch: binary-parser Package.swift comment repoints swallowed by the wiring commit, completed post-merge as `85e47bd1`).
