---
date: 2026-05-01
session_objective: Close Wave 4c envelope (Socket Main + Prerequisite II + tail + Poll + File-Stats + Process-User-Group) and rewire swift-console to L3-unifier per Finding 6.8
packages:
  - swift-iso-9945
  - swift-posix
  - swift-windows
  - swift-windows-32
  - swift-kernel
  - swift-console
  - swift-institute (Skills + Audits)
status: pending
---

# Wave 4c Envelope Completion + Finding 6.8 swift-console Rewire

## What Happened

The session opened mid-Wave-4c-Socket-Prerequisite-I — Phase 5 audit doc
update was the immediate task. Six dispatches followed in sequence:

1. **Wave 4c-Socket Prerequisite II** (corrective) — Prerequisite I's
   skill revision had landed framing that the L3-unifier "typealiases
   directly to L2, skipping the L3-policy hop." This violated
   [PLAT-ARCH-008e]'s composition discipline (L3-unifier composes its
   peer L3-policy tier; never reaches across into L2). The skill text
   preceded executable code (`f703ad3`) which mirrored the violation.
   Prerequisite II re-revised the skill to codify the three-tier chain
   explicitly, then fixed the code: `Package.swift` direct L2 deps
   dropped (swift-iso-9945, swift-windows-32); `Exports.swift`
   typealiases retargeted from L2 names to L3-policy names (POSIX.Kernel.X
   / Windows.Kernel.X); source imports replaced (`POSIX_Kernel_Descriptor`
   etc.); `@_exported public import POSIX_Kernel_Socket` substituted for
   `@_exported public import ISO_9945_Kernel_Socket`.

2. **Wave 4c-Socket Main** — typed Phase-1.5 forms re-added at
   `ISO_9945.Kernel.Socket.{Bind,Listen,Accept,Connect,Send,Receive,
   Shutdown,Option,Name,getError}`. 24 typed forms; 24 raw companions
   downgraded `@_spi(Syscall) public` → `internal`. Introduced typed
   `Option.Name` (RawRepresentable<Int32>, mirrors Level) after
   principal corrected mid-flight that `name: Int32` was insufficiently
   typed. Cycle 21 file-comment annotations updated (every
   "L1-domain-only" banner → "Wave 4c-Socket Main per [PLAT-ARCH-005]").
   141 LOC of swift-posix Compat.swift deleted (replaced by L2 typed
   forms); 13 swift-posix consumer call sites migrated.

3. **Wave 4c-File-Stats + Process-User-Group** — both near-no-ops; the
   typed forms (`get(descriptor:)`, Process.ID/User.ID/Group.ID typed
   wrappers) already existed. File-Stats raw `get(fd:)` downgraded to
   internal; nothing to migrate at L3.

4. **Wave 4c Acceptance Tail (Tagged Primitives Test Support dep)** —
   small Package.swift dep addition; build progresses past the named
   import error.

5. **Wave 4c Acceptance Tail Cycle A (test rename)** — empirical
   re-grep showed the rename scope was 107 test files / ~2k LOC, not
   the 30-40 lines my halt-report estimated and not the "100+" the
   principal estimated. Mechanical sed `Kernel.X` → `ISO_9945.Kernel.X`
   across `Tests/ISO 9945 Kernel Tests/`; 61 files received
   `import ISO_9945_Kernel`. Build progresses past the rename errors;
   surfaces unrelated pre-existing test source drift (Socket.Error.handle
   case missing, Tagged_Primitives_Standard_Library_Integration
   MemberImportVisibility) which I correctly halted on per ground rule
   #3.

6. **Wave 4c-Poll** — typed Poll.Entry init already existed at L2;
   only Connect.swift:66 migration + raw companion downgrade remained.
   Discovered redundant L3 POSIX.Kernel.Poll.Entry shim at swift-posix
   that broke when L2 raw was downgraded; deleted it (same pattern as
   Compat.swift deletion in Socket Main).

7. **Finding 6.8 — swift-console rewire** — Package.swift swift-posix
   → swift-kernel + Kernel Terminal; imports POSIX_Kernel → Kernel.
   Discovered swift-console had pre-existing breakage: orphan imports
   of deleted L1 modules (`Kernel_IO_Primitives`, `Kernel_File_Primitives`)
   that didn't build at HEAD even before my rewire. `git stash` of my
   changes confirmed pre-existing. Replaced orphan imports with
   `import Kernel` (resolves Kernel.IO.Read.Error via three-tier
   typealias chain) + added `import Kernel_Terminal` for the Cycle
   22-relocated Terminal.Mode.Raw.Token. 44 tests pass.

**Session totals**: ~13 commits across 6 repos; ~2.3k LOC changed
(of which ~2.1k in test rename mop-up); audit doc ~250 lines added.
Wave 4c envelope: 10 sub-cycles closed; only deferred items are the
deinit-helper architectural follow-up + Wave 3.5 + Tier 5.

## What Worked and What Didn't

**Worked**:

- **Stop-and-report on dispatch ground rule triggers**. Cycle A
  surfaced unrelated test source drift (Socket.Error.handle missing
  case, MemberImportVisibility on Tagged_Primitives_Standard_Library_Integration)
  past the rename scope. I correctly stopped per ground rule #3 and
  reported. The principal's dispatch had explicit "ask: if non-trivial,
  stop" — the stop fired cleanly.
- **Three-tier chain mechanism**. Prerequisite II's typealias chain
  (`Kernel.X → POSIX.Kernel.X → ISO_9945.Kernel.X`) made the entire
  Wave 4c-Socket Main mechanical: L2 typed forms take borrowing typed
  Descriptor; L3-policy holds typealias; consumer passes typed
  Descriptor through. No round-trips. This was the architectural
  payoff for Prerequisite I + II.
- **Auto-mode discipline**. Per the system instruction "minimize
  interruptions, prefer action over planning" + the dispatch's
  envelope, I executed continuously through the autonomous tail
  (Wave 4c-File-Stats + Process-User-Group) without re-asking,
  closing both as near-no-ops with a single audit-doc commit. The
  envelope contract worked.
- **Principal correction integration mid-flight**. Mid-Socket Main,
  principal flagged `name: Int32` as not high-typed enough. I
  introduced `Option.Name` typed wrapper mirroring the existing
  `Level` pattern, updated typed forms, kept moving. The correction
  didn't derail the dispatch.

**Didn't work**:

- **Skill text drove code into a violation**. Prerequisite I's skill
  revision said "the L3-unifier typealias chain resolves directly to
  the L2 canonical types, skipping the L3-policy hop." This phrase
  was novel-shaped — no prior platform skill statement framed
  composition as "skipping" a tier. The Wave 4c-Socket Prerequisite I
  code commit (`f703ad3`) mirrored the framing exactly. Prerequisite II
  identified that this violated [PLAT-ARCH-008e]. The wrong-skill-then-
  wrong-code pipeline meant a corrective sub-cycle was needed.
- **Mechanical-estimate undercount**. My halt-report after the Cycle A
  empirical grep estimated 30-40 lines for the test rename. The
  principal's revised dispatch estimated "likely 100+." The actual
  scope was 107 files / ~2k LOC + 61 missing imports. Both estimates
  were off by 5x-10x. The grep used at halt time over-filtered
  (`grep -v 'ISO_9945\.Kernel'` swallowed lines containing both
  qualified and unqualified references, undercounting).
- **Build-cache staleness after file deletion** required `rm -rf .build`
  on 4 downstream packages (swift-linux, swift-kernel, swift-io,
  swift-executors) when I deleted POSIX.Kernel.Compat.swift in Socket
  Main and POSIX.Kernel.Poll.Entry.swift in Wave 4c-Poll. SwiftPM
  caches the file list per target; deleted files surface as "missing
  inputs" until cache is invalidated. Took ~3 minutes of total wall
  clock to rebuild four packages.
- **Initial sed for raw-companion downgrade dropped a space** —
  `s/    @_spi(Syscall)\n    public static func /    internal static func/`
  joined `func` to the function name. Caught immediately by the build
  but cost a corrective sed pass. Multi-line sed across many files
  is error-prone; per-file Edit with explicit old/new text is safer.

## Patterns and Root Causes

**The skill-text-precedes-code pipeline is a recurring high-risk
pattern.** Prerequisite I's revision was authored as "additive
clarification" but the language ("skipping the L3-policy hop")
introduced a novel composition shape that conflicted with existing
[PLAT-ARCH-008e]. The skill text then guided the executable code
verbatim. Two failures stacked: (1) the skill text was not
cross-audited against sibling composition rules at edit time;
(2) the implementing session ([f703ad3]) treated the skill as
authoritative and didn't re-derive from sibling rules.

This is the same shape as the recurring "specific-rule wins over
general-rule" failure: a narrow rule revision can land that
contradicts a broader rule, and the implementer follows the narrow
one because it was more recent. The fix is at the skill-edit gate,
not the implementer: skill revisions that propose architectural
shape MUST cross-reference sibling composition rules before
adoption. [PLAT-ARCH-008e] / [PLAT-ARCH-008c] / [PLAT-ARCH-008j]
are the platform composition triad; any skill-text change touching
how layers compose must verify against all three.

**Mechanical-rename estimates undercount because the grep-pattern
gates undercount.** Both my 30-40 estimate and the principal's 100+
came from the same kind of grep with imperfect filters. The actual
mechanical scope is the union of: (1) bare reference sites,
(2) sites missing the qualifying import. Counting only (1) misses
the import additions that fall out of (2). The Cycle A actual
breakdown: 107 files with `Kernel.X` references + 61 files missing
`import ISO_9945_Kernel` (many overlapping). Future rename
estimates should explicitly include the import-addition cost.

**Build-cache staleness after file deletion is invisible until
downstream build.** SwiftPM tracks the target's file list at cache
time; deleted-but-cached files reappear as "missing inputs" only
when a downstream package consumes the target. The pattern is:
delete file at L2/L3 → L2/L3 builds clean (re-emits target) →
downstream package builds against stale cache → "missing inputs".
The fix is `rm -rf .build` on the downstream package, but the
trigger is non-obvious. A workspace-wide policy: after deleting
files, clean downstream package caches before reporting build
green.

**Auto-mode + envelope contract works.** The dispatch's
"After this cycle green-closes, continue autonomously through the
remaining envelope" pattern let the session push from
Wave 4c-Socket Main → File-Stats → Process-User-Group → Acceptance
Tail → Poll → Finding 6.8 → close in one continuous arc, with the
principal stepping in only when (a) correcting a typed-parameter
quality issue or (b) authorizing the next dispatch. The envelope
acts as durable authorization for the mechanical tail; the
principal stays in the loop only for novel decisions. This
matches the supervise-skill pattern where principal steers,
subordinate executes.

## Action Items

- [ ] **[skill]** platform: codify "skill-text-precedes-code"
  cross-audit gate. When a skill revision proposes new
  architectural shape (composition direction, layer skipping,
  typealias chain shape, namespace identity), the revision MUST
  cross-reference all sibling composition rules ([PLAT-ARCH-008c],
  [PLAT-ARCH-008e], [PLAT-ARCH-008j]) at edit time and verify the
  proposed shape doesn't contradict any. The Prerequisite I skill
  text passed [SKILL-LIFE-003] CLARIFYING+ADDITIVE classification
  but failed cross-rule audit; the corrective Prerequisite II
  established the missing gate. Provenance: this session's
  Prerequisite II close-note + the [PLAT-ARCH-005] Prerequisite II
  re-revision.
- [ ] **[skill]** code-surface: codify typed-parameters principle
  beyond Descriptor. Typed-everywhere is not just "wrap the
  Descriptor"; ALL platform-constant parameters (typically
  Int32 representing C macros like `SO_REUSEADDR`, `SOL_SOCKET`)
  need typed wrappers when introducing typed L2 forms. The
  pattern: when a typed L2 form takes `Type1, Type2, Int32` and
  the Int32 represents a platform-namespaced constant set, the
  Int32 gets a `RawRepresentable<Int32>` typed wrapper mirroring
  any existing peer (e.g., Option.Name mirrors Option.Level).
  Provenance: principal's mid-flight correction during
  Wave 4c-Socket Main; Option.Name addition.
- [ ] **[research]** post-Path-X test namespace drift survey —
  Cycle A surfaced 107 test files at swift-iso-9945 alone using
  `Kernel.X` (L3-unifier name) where `ISO_9945.Kernel.X` (L2
  spec name) is required. Other ecosystem packages with their
  own test suites (swift-foundations test targets, swift-primitives
  test targets) may have analogous drift if they were authored
  pre-Path-X and not migrated. A survey grep across all `Tests/`
  directories would inventory the remaining cleanup scope; if
  large, this becomes a separate Wave (Wave 4d-Test-Migration?);
  if small, a single mop-up commit closes it.
