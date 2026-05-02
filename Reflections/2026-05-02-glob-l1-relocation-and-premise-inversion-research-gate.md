---
date: 2026-05-02
session_objective: Execute Item 3.5 Option B (Glob vocabulary L2→L1 relocation) after pre-flight research confirmed dispatch's premise inversion
packages:
  - swift-glob-primitives
  - swift-iso-9945
  - swift-posix
  - swift-windows
status: pending
---

# Glob L1 Relocation Cycle and the Premise-Inversion Research Gate

## What Happened

Multi-cycle relay session continued from prior compaction. Four cycles dispatched
in sequence under [SUPER-002] ground rules:

1. **Cycle 1** (resumed) — Tier 5-Windows-FOS+Affinity-Combined: recreated File
   Offset/Size/Delta + Thread.Affinity at swift-windows-32 L2 + L3-policy
   per-domain targets at swift-windows + L3-unifier dispatch reintroduction at
   swift-kernel. Closed at commits `7509c37`/`cc5ff79`/`d36c9fe` (windows-32),
   `f40a2e9`/`8952d21` (windows), `f6b1f7b` (kernel).

2. **Cycle 2** — Tier 5-Windows-Event Direction (iii) architectural-minimalist:
   added `Windows.\`32\`.Kernel.IO.Completion.Port.wakeup() -> @Sendable () -> Void`
   parity wrapper around `PostQueuedCompletionStatus` (commit `00bbd8d`); doc-only
   update to `Kernel.Event.Source+Platform.swift` Windows branch citing
   Kernel.Completion as the cross-platform IOCP path (commit `b74a5a6`). Closed
   the Tier 5-Windows-Mirror sub-envelope at 3/3.

3. **Cycle 3** — Item 3.5 pre-flight research: produced
   `Research/glob-l1-vocabulary-relocation.md` with 5 sub-sections (placement,
   [PLAT-ARCH-005] applicability, consumer cascade, cross-platform constraints,
   recommendations). **Detected premise inversion**: dispatch assumed Glob
   vocabulary was at L1 awaiting consumer-cascade work; actual state was at L2
   (`ISO_9945.Kernel.Glob.*`) with swift-windows depending on a POSIX-named
   package for platform-agnostic vocabulary. Surfaced 5 sub-questions for
   principal disposition rather than executing on the wrong premise.

4. **Cycle 4** — Item 3.5 Option B execution: created `swift-glob-primitives` L1
   with top-level `Glob.*` namespace (NOT `Kernel.Glob.*`); deleted 14
   `ISO_9945.Kernel.Glob.*.swift` files at swift-iso-9945; rewired swift-posix
   (commit `97de148`) and swift-windows (commit `45c9d04`); kept libc
   `ISO_9945.Glob.{Fnmatch,Expand}` at L2 per [PLAT-ARCH-005]. Side effect:
   swift-windows now holds zero swift-iso-9945 dependencies. Documentation closed
   at swift-institute/Audits `4bcc8fa` + Research `de24e30`. Memory recorded at
   `project_glob_l1_relocation_complete.md`.

**HANDOFF scan**: 6 files found at workspace root.

| File | Triage outcome |
|---|---|
| `HANDOFF-tier-5-windows-mirrors-2026-05-02.md` | Annotated-and-left (TERMINAL CLOSURE 3/3 already in file lines 271–326; deletion deferred — parent dispatch artifact, audited via [REFL-009a] in-flight conservativism since the broader Tier 5 envelope close is principal-active) |
| `HANDOFF-tier-5-vocab-relocation-2026-05-02.md` | Out-of-cleanup-authority (POSIX-side Tier 5 vocab envelope; this session worked Windows-side mirrors + Item 3.5, did not touch POSIX-side) |
| `HANDOFF-post-path-x-final-architectural-cycles.md` | In-flight conservativism per [REFL-009a]: parent handoff lists 6 architectural items, only Item 3.5 closed this session; principal active across remaining items. No annotation. |
| `HANDOFF-l3-policy-layering-without-spi-experiments-2026-05-02.md` | Out-of-cleanup-authority (different topic, this-day-authored by principal, not worked) |
| `HANDOFF-corpus-phase-7a-toolchain-revalidation.md` | Out-of-cleanup-authority (April 30 corpus revalidation, untouched) |
| `HANDOFF.md` | Out-of-cleanup-authority (Property family rename design, untouched this session) |

## What Worked and What Didn't

**Worked:**
- The pre-flight research dispatch (Cycle 3) caught the premise inversion before
  any source-code work. Had Cycle 4 fired immediately on dispatch's "Glob is at
  L1, do consumer cascade" framing, the cycle would have produced wrong-direction
  consumer rewrites against an L1 package that did not exist. Surface-cost: one
  research deliverable + 5 sub-questions. Saved-cost: an entire reverse cycle.
- Targeted `swift build --target` library-only verification cleanly isolated my
  changes from the pre-existing 787 swift-file-system errors (Item 1.5
  territory). Carve-out per ground rule #4 held.
- Internal-import downgrade pattern at swift-posix (`public import ISO_9945_Glob`
  → `internal import ISO_9945_Glob`) cleared the unused-public-import warning
  cleanly once `public import Glob_Primitives` was added — the ISO 9945 import
  remained needed only for libc `Fnmatch.Options`, which is implementation-
  internal.
- Per-repo commit discipline (Audits + Research separately) avoided the
  "swift-institute is not a git repo" trap from prior sessions.

**Didn't:**
- Phase 1 shell loop `for f in Glob.*.swift; do ...; done` did not match
  `Glob.swift` (no middle component between `Glob` and `.swift`). The namespace
  anchor file silently kept its old `extension ISO_9945.Kernel { public enum Glob {} }`
  form. Caught only because subsequent build failed; required manual rewrite to
  the new top-level `public enum Glob {}` shape. Cost: one extra Read+Write cycle.
- Phase 3 `sed -i '' 's/\bISO_9945\.Kernel\.Glob\.\b/Glob./g'` left 59 references
  unchanged in the test file because BSD sed does not support `\b` (treats it as
  literal `b`). Detected only because grep confirmed surviving references.
- The status of `HANDOFF-tier-5-windows-mirrors-2026-05-02.md` is now
  3/3-CLOSED-but-still-on-disk; deletion was the correct disposition per
  [REFL-009] (work complete, no unverified ground-rules entries). Held back via
  in-flight conservativism because the broader Tier 5 envelope is principal-
  active. This is the correct disposition but it leaves a stale-on-its-own-terms
  artifact at root for [HANDOFF-038] orphan-zone tracking.

## Patterns and Root Causes

**Pattern 1 — Premise-inversion catch via research gate.** The dispatch's framing
("Item 3.5 deferred from final architectural cycles") encoded a premise: that
Glob vocabulary was already at L1 and needed only a consumer-cascade rewire. The
actual state was the inverse. Pre-flight research surfaced this *before* any
source-code work; Cycle 3's deliverable was effectively a question reframing
("you asked how to migrate consumers; the prior step — moving the vocabulary to
L1 — has not happened yet"). This is a generalizable pattern: when a dispatch
says "do step N of plan X," verify steps 1..N-1 actually completed before
executing N. Especially valuable for cycles authored by principal weeks earlier
where intermediate steps may have been deferred or never executed. The cost
asymmetry is severe — research deliverable is hours; reverse cycle is days.

**Pattern 2 — The namespace-anchor file falls outside `X.*.swift` patterns.**
`Glob.*.swift` matches `Glob.Atom.swift`, `Glob.Pattern.swift`, etc., but NOT
`Glob.swift` (which has no middle component). The namespace anchor file (the
one declaring `public enum Glob {}` itself) is structurally different from the
nested-type files but visually clusters with them. Rename loops, sed sweeps, and
target-membership checks that use middle-component-required globs miss the
anchor every time. Prior sessions hit this on similar relocation cycles. Two
fixes: (a) use `Glob*.swift` (no required dot — but matches more than intended
when other prefixes share the stem), or (b) explicitly handle `X.swift`
separately as the namespace-anchor case. Worth a feedback memory.

**Pattern 3 — Architectural fact buried in package dependency.** swift-windows
depending on swift-iso-9945 *for Glob vocabulary* was not a typed-system
violation — it compiled, it built, it worked. The violation was at the package-
authority layer: a Windows package depending on a POSIX-named package for
platform-agnostic vocabulary. The asymmetry was invisible at the call-site
(`Glob.Pattern` looks identical regardless of who declares it) and only visible
at the package-graph layer. `feedback_authority_not_platform` codifies the rule;
the cycle eliminated a concrete instance. Generalizable detection: grep
`swift-windows*/Package.swift` for any `swift-iso-*` or `swift-posix*` deps —
each is a candidate for the same pattern. Post-relocation: zero matches.

## Action Items

- [ ] **[skill]** implementation: Add a sed/grep guidance line: "BSD sed (macOS default) does not support `\b` word boundary; use `[^A-Za-z_]` boundary classes or explicit context. Same applies to `sed -E` extended regex flag." This recurs across rename cycles.
- [ ] **[skill]** modularization: Add namespace-anchor caveat to relocation/rename guidance: "When iterating files of a relocated namespace via shell glob, `X.*.swift` does NOT match `X.swift` (the namespace anchor). Handle the anchor file explicitly. Verify post-loop with `grep -L new-pattern X*.swift` to catch missed files."
- [ ] **[research]** Cross-platform package-dependency audit: are there other instances where a Windows-side package depends on a POSIX-named package for platform-agnostic vocabulary? Grep `swift-microsoft/*/Package.swift` and `swift-windows*/Package.swift` for `swift-iso-*` / `swift-posix*` deps; each is a candidate for the same Item 3.5 pattern. Likely 0–2 instances given Path X's prior cleanup, but worth confirming systematically.
