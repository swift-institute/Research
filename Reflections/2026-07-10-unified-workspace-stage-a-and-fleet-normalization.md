---
date: 2026-07-10
session_objective: Resume the unified-workspace arc (Stage A core green), then execute the evening checkpoint (fleet normalization, consolidated push, overnight dispatch)
packages:
  - institute.xcworkspace (Workspace)
  - swift-rfc-8446
  - swift-rfc-6455
  - swift-rfc-3596
  - swift-rfc-7301
  - swift-time-based-one-time-password
  - swift-password
  - swift-memory
  - swift-darwin
  - swift-iterator-primitives
  - swift-email-standard
  - swift-throttling
  - swift-html-chart
status: pending
---

# Unified Workspace Stage A: from poisoned resolve to a pushed, normalized fleet

## What Happened

Resumed HANDOFF-workspace-pivot at ~14:45 with one probe. The day's arc, compressed:
(1) The workspace resolve was effectively hung (27+ min at 99% CPU). Static
analysis — mirror-table check (IN SYNC), scan-identity-conflicts (4 HARD local
+ 12 committed path-deps at HEAD), and purpose-built session scanners
(constants-aware manifest parsing) — located three poison classes: identity/
location divergences (§A26), boiler's unsolvable version chain (the GUI error
screenshot), and cross-member target-name collisions (mailgun family: 19
identical target names across 3 repos, invisible to literal-only grep).
(2) Principal ruled exclusion-first + institute-purity (closure ⊆ institute +
apple/swiftlang): the purity classifier cut 18 tainted members; the final core
is 395 members resolving in ~2.5–3 min. Xcode GUI crashes were root-caused to
IDESourceControlWorkspaceMonitor segfaulting on ~400 working trees (SCM
integration disabled; crash gone).
(3) The per-scheme error-inventory sweep was retired after measuring ~2 min of
graph re-resolution PER xcodebuild invocation (~15 h fleet-wide); replaced with
one generated workspace-level mega-scheme (institute-ALL, 1,969 targets, one
resolve, wrote 417 per-package aggregate schemes too — xcodebuild does NOT
materialize -Package schemes on demand). Inventory delivered: 13 broken
packages / 8 root-cause families / 385+ clean (CLASSIFIED.md).
(4) Step-3 lanes fixed and I gate-verified + committed all mechanical families
(13 commits, 12 repos): Radix rename-follow ×2, darwin/memory test drift,
TOTP + password dependencies-API migrations (three-move recipe distilled),
email-standard byte-discipline, rfc-3596's retroactive-conformance adoption,
rfc-7301 MemberImportVisibility imports, iterator diagnostic-failure
workaround. tree-n + set-algebra (structural, Phase-2c terrain) and rfc-7230
(Foundation remnants + URI reshape) were excluded to rework lanes.
(5) Evening checkpoint per principal: fleet normalization (tools 6.3.3 across
581 manifests via the patched sync-tools-version.sh; variant manifests
eradicated — exactly 4 existed, one of which governed swift-password with
tools-5.10-main + legacy deps and caused 20-min resolver stalls; language mode
pure [.v6]); fleet compile gate (mega build; residue = exactly two mechanical
clusters + an untriaged C-shim class, all handed to overnight); mass-commit
(425 surgical bump commits); consolidated push 430/430 (2 rebases over
foreign-lane commits); Workspace + Scripts committed/pushed; overnight
dispatch written (HANDOFF-overnight-2026-07-10) and GO given at ~23:00.
Parallel: a Fable fork charted the repotraffic tower (27 direct / ~70 closure,
5 choke points) — plan RATIFIED with the two-pass refinement (works-first,
native-second).

HANDOFF scan (store = Workspace/handoffs/, guard reads 70>40 — documented
overage per the 2026-07-06 cap ruling; both live arcs remain open, per-arc
drain applies at close, no bulk triage tonight): 4 files in this session's
authority, all annotated-and-left with reason — HANDOFF-workspace-pivot
(live arc, Current State refreshed in place ×3), HANDOFF-overnight (fresh
dispatch, work not started), PLAN-repotraffic-tower-adaptation (ratified,
awaiting Wave-0), HANDOFF-overday (predecessor's historical record, referenced
by the pivot handoff; out of deletion scope). No root-level handoffs. No
/audit ran this session.

## What Worked and What Didn't

Worked: static-first diagnosis (the identity/collision/purity scanners found
every graph-fatal class before any build finished); exclusion-first with
documented re-add conditions; the lane pipeline (edit-only subagents, gates+git
in coordinator, SendMessage follow-ups to warm lanes — the TOTP lane's second
package took one message); the 5-min reaction rule with sample-then-kill; the
principal's skepticism ("20-min checkout is not my experience") directly
overturned my wrong normal-cold-build rationalization — the stall was a
governing variant manifest, found within minutes of taking the challenge
seriously.

Didn't: I rationalized two anomalies before evidence (the 20-min "cold build",
the "checkout time") — both times the user's experience was the better prior.
Two Claude sessions mutually killed each other's probes before coordination
was established (ONE session owns workspace ops). My first collision scan
missed constant-style declarations entirely (literal-only regex) — a false
all-clear that the constants-aware v2 overturned; same class as the comment-
stripper eating https:// URLs. Loop/monitor plumbing bugs recurred (pipe-status
vs $?, monitor self-match in pgrep patterns) — [REFL-012]'s no-op-check family,
now fixed in the gate procedure. The compat-alias detour (product aliases for
legacy askers) was resolve-safe but PIF-fatal (duplicate product GUID killed
every scheme) — exclusion-first was ratified only after that failure.

## Patterns and Root Causes

The day's unifying pattern: **a tool's green (or a tool's hang) is a claim
about the tool's reach, not about the world** — [REFL-011]'s tool-reach
extension fired at least five times. The literal-only grep's "0 collisions,"
the `rm -rf .build` "cold" build, the `rm Package.resolved` "fresh" resolve
(shared cache served a pre-rename bare repo), the loop counter vs pipestatus,
and the heartbeat monitor whose death-check matched its own command line. The
fix was the same every time: align the check's reach with the claim
(constants-aware parsing, `swift package update`, PID files, state checks).

Second pattern: **manifests have more than one truth surface.** A variant
manifest can silently govern over the file everyone edits; a product ask can
name a module the manifest never declares (tolerated until MemberImport-
Visibility/explicit modules); a product alias satisfies SwiftPM's resolver but
collides at Xcode's PIF layer where GUIDs derive from product names. All three
argue for one-manifest-per-package + spelled-out imports/products as
enforceable invariants, not conventions.

Third: **workspace-scale inverts build economics.** Per-invocation graph
resolution (~2 min at 400 packages) makes per-package xcodebuild sweeps
infeasible (~15 h); one mega-scheme with all targets makes the fleet buildable
in ~40 min cold / ~15 min warm. Conversely, member roots override same-identity
URL deps — which is the workspace's whole point — so workspace-green diverges
from standalone-green precisely where pins/caches/variant manifests differ:
the gates must stay standalone.

## Action Items

- [ ] **[skill]** swift-package: add a [PKG-DEP-*] rule — ONE manifest per
  package; `Package@swift-*.swift` variants are forbidden fleet-wide
  (principal ruling 2026-07-10); include the governing-variant trap (tools-
  version selection makes the variant the real manifest) and the swift-password
  incident; enforcement candidate: a validator + the patched
  sync-tools-version.sh (now all-org, pruned, 6.3.3 canonical).
- [ ] **[skill]** swift-package-build: add workspace-scale rules — (a) per-
  invocation graph-resolve cost makes per-scheme sweeps infeasible; the
  generated all-targets workspace scheme is the fleet-build pattern (generator
  + 417 aggregate schemes; xcodebuild does NOT auto-materialize -Package
  schemes); (b) product aliases are resolve-safe but PIF-unsafe whenever any
  graph package vends the same product name (duplicate GUID → workspace-wide
  "Could not compute dependency graph"); (c) NO TOOLCHAINS for xcodebuild ops
  (breaks manifest compilation — clang posix_spawn); (d) IDESourceControl
  disable for >100-repo workspaces (SIGSEGV class).
- [ ] **[research]** Author the Issues/ dossier + swift-compiler-bug-catalog
  entry for the swiftc diagnostic-engine failure ("failed to produce
  diagnostic", 6.3.2 AND 6.3.3): two constrained-extension generic
  `reduce(into:)` overloads + implicitly-typed closure; reduced reproducer =
  Iterable+Reduce.swift pair + untyped closure; workaround committed
  (explicit closure typing, swift-iterator-primitives fce7c86).
