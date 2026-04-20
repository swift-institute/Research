---
date: 2026-04-20
session_objective: Execute the NUL-cascade fix dispatched by HANDOFF.md, then refactor File.Name to adopt ecosystem Path.Char vocabulary
packages:
  - swift-file-system
  - swift-kernel-primitives
  - swift-string-primitives
  - swift-path-primitives
status: processed
processed_date: 2026-04-20
triage_outcomes:
  - type: skill_update
    target: handoff
    description: [HANDOFF-016] extended with scope-flag-staleness axis
  - type: skill_update
    target: implementation
    description: [PATTERN-056] dead-case-per-platform enum anti-pattern
  - type: skill_update
    target: reflect-session
    description: Post-commit memory scan step added to [REFL-006]
---

# File.Name NUL fix execution and Path.Char adoption

## What Happened

Continuation of the session captured in `2026-04-20-swift-file-system-io-migration-and-l1-vocabulary-overreach.md`. That earlier session diagnosed the NUL cascade, wrote a fresh `HANDOFF.md` dispatching the fix, and reverted a sibling agent's speculative L1 work. This session executed the dispatched work and — prompted twice by supervisor and user — iterated through three progressively-better shapes.

**Setup.** Verified handoff state against git: matched exactly (swift-kernel-primitives uncommitted WIP, swift-file-system on `86f83ef`, swift-kernel on `5180afc`). Reverted the sibling WIP in kernel-primitives: `git checkout` 2 modified files, `rm` 4 untracked files + superseded `HANDOFF-directory-entry-platform-neutral-name.md`. Clean rebuild of kernel-primitives passed.

**Iteration 1 — the handoff's prescribed sketch.** Applied `Array(entry.nameView.span)` in `File.Name.init(from:)` per the handoff's Step 2 sketch. Did not compile — `Array` has no `init(_ span: Span<Element>)` in this toolchain. Fell back to the handoff's stated fallback: `entry.nameView.withUnsafePointer { ptr in Array(UnsafeBufferPointer(start: ptr, count: count)) }` plus the analogous change in `File.System.Delete.swift:212`. 709/709 tests passed. Committed as `c3b9986` "Fix File.Directory.Entry NUL leak via nameView.span" with the verification stamp per `[SUPER-011]` in HANDOFF.md Constraints.

**Iteration 2 — supervisor's unsafe catch.** Supervisor reviewed and approved the bug fix but flagged that the chosen shape had two `unsafe` keywords and two `UnsafeBufferPointer` references inside an L3 consumer site. Cited my own memory `feedback_no_unsafe_api_surface`. Proposed Span-indexed iteration: `for i in 0..<span.count { bytes.append(span[i]) }`. Applied to both sites. 709/709 still passed. Held the commit pending user approval per the supervisor's deviation note (approved shape used `withUnsafePointer`, Iteration 2 replaced it).

**Iteration 3 — user's ecosystem-adoption challenge.** User asked: "didn't we say NO platform conditionals in swift-file-system?" I advised that the `#if os(Windows)` in `File.Name.init(from:)` was structurally required because `File.Name.RawEncoding` is a two-case enum (`.posixBytes([UInt8])`, `.windowsCodeUnits([UInt16])`) with per-platform element types; cited `[PLAT-ARCH-008a]` domain authority. User redirected: "the main improvement here is ecosystem type adoption better. I'm sure the problem is we're trying to solve a solved issue."

Dispatched an Explore agent to sweep ecosystem research on strings/paths/names across seven directories (swift-institute/Research/, swift-string-primitives/Research/, swift-path-primitives/Research/, swift-kernel-primitives/Research/, swift-kernel/Research/, swift-foundations/swift-file-system/Research/, plus related Documentation.docc/). Agent report: three owning string types exist (`String_Primitives.String`, `Kernel.String`, `ISO_9899.String`), `string-type-ecosystem-model.md §D1` bans a fourth, and `String_Primitives.String.Char` is already a platform-conditional typealias (`UInt8` POSIX / `UInt16` Windows) chained through `Path.Char` via `swift-path-primitives/Path.swift:59`. Verdict: `File.Name.RawEncoding`'s two-case enum with a dead case per platform is re-solving — poorly — what `Path.Char` already provides.

Presented three scope options. User approved option 3 (refactor in a separate commit on top of `c3b9986`, "cleaner git history, same end state").

**Refactor.** Rewrote `File.Name.swift`: replaced `rawEncoding: RawEncoding` with `rawBytes: [Path.Char]`, added `File.Name.Encoding` typealias (`UTF8` POSIX / `UTF16` Windows) so `Swift.String(decoding: rawBytes, as: File.Name.Encoding.self)` handles lossy decode without a `switch` at the call site. Deleted `File.Name.RawEncoding.swift`. Updated consumer switch sites: `File.Name.Decode.Error.debugRawBytes`, `File.Directory.Entry.path()`, `File.System.Copy.Recursive`'s inline component construction. First compile attempt failed at `var bytes: [Path.Char] = []` with "'Path' is ambiguous" — `Path_Primitives.Path` vs `Paths.Path` (File.Path). Module-qualified to `Path_Primitives.Path.Char` per `feedback_module_disambiguation_not_rename`; compiled. 709/709 tests passed. Committed as `4515c23` "Refactor File.Name storage to adopt Path.Char vocabulary", net +141/-205 across 6 files.

**Final state.** Two commits on swift-file-system `main`: `c3b9986` (NUL fix) + `4515c23` (Path.Char refactor). The `#if os(Windows)` that was in `init(from:)` is gone. The 14 `switch rawEncoding` sites are gone. One class of dead-case-per-platform enum is gone. swift-kernel-primitives untouched since the revert. swift-kernel untouched. HANDOFF.md has verification stamp; gitignored.

## What Worked and What Didn't

**Worked — module-qualified disambiguation over rename.** First `Path.Char` attempt failed due to `File.Path` (`Paths.Path`) ambiguity in the init body scope (the field declaration at line 39 compiled; the local variable at line 167 didn't — same identifier, different scopes). Reached for `Path_Primitives.Path.Char` per `feedback_module_disambiguation_not_rename` memory. Compiled without needing a typealias bridge or a rename. Memory consultation worked here; the explicit rule did its job.

**Worked — Explore agent for the research sweep.** Seven directories, a canonical reference document, three owning-type inventory, D1/D4/D7/Q4 extraction. Agent produced a self-contained report in one dispatch. Would have cost 20+ main-context tool calls to do in-line. The agent's inventory table was directly actionable — I used it to justify the refactor to the user and to name `File.Name.Encoding` by analogy with `String_Primitives.String.Char`.

**Worked — two-commit landing.** User asked for it specifically (option 3). `c3b9986` is the minimal bug fix; `4515c23` is the pure refactor. A reviewer can revert either independently. If the refactor uncovered a regression later, the bug fix still stands. Cheap git hygiene.

**Didn't work — I defended the `#if` in my advisory reply.** When the user asked "didn't we say NO platform conditionals?", I cited `[PLAT-ARCH-008a]` domain authority (PROVISIONAL, requires user confirmation) and concluded "my recommendation: keep it, it's structurally required." That was technically correct about the exception but missed the question the user was actually asking. The user was not asking "is the `#if` *permitted*?" — they were asking "is the `#if` *necessary*?" I answered the first; they wanted the second. Rule adherence as cover for lack of deeper thought.

**Didn't work — I treated handoff scope as binding.** The handoff explicitly said "File.Name.RawEncoding's own `#if` and per-platform storage — part of the broader D1 unification. Separate task." I read that as "RawEncoding stays as-is." The handoff's author (a prior session of me) had scoped it out on the assumption that RawEncoding was correct. When the user surfaced that RawEncoding was *wrong* (re-solving a solved problem), the out-of-scope label was stale in the exact sense of `[HANDOFF-016]` — not about work staleness but about prescription staleness: the author's *assumption* about the excluded item was wrong, so the exclusion flag dissolved.

**Didn't work — supervisor had to surface my own memory.** `feedback_no_unsafe_api_surface` says L3 consumer sites should keep `unsafe` inside implementation bodies, not in the API surface shape. I applied the handoff's `withUnsafePointer + UnsafeBufferPointer` pattern without scanning my feedback memory for adjacent rules. Memory existed; consultation didn't. The supervisor's catch was a prosthetic for that gap. One round trip of rework (Iteration 1 → 2) could have been avoided with a 10-second memory scan.

**Didn't work — three iterations on what was one conceptual problem.** Iteration 1 (unsafe fallback): correct as a mechanical fix to compile error, introduced a code-quality regression. Iteration 2 (Span-indexed): correct as a fix to Iteration 1's regression, kept the `#if`. Iteration 3 (refactor): correct as a fix to the `#if`, which was caused by the type's shape. Each iteration was locally optimal; none was globally optimal. The global answer — adopt `Path.Char`, delete `RawEncoding` — was available from Iteration 1 if I had asked "why does this type have two cases?" instead of "how do I copy this span?"

## Patterns and Root Causes

**The out-of-scope-as-stale-prescription pattern.** `[HANDOFF-016]` distinguishes work staleness (completed Next Steps) from proposal staleness (stale branch names, API signatures). There is a third category not currently named: **scope-flag staleness**. When a handoff says "X is out of scope," that flag is grounded in the author's *understanding* of X. If session work reveals that understanding is wrong — the thing the author scoped out is in fact the root cause of the task — the scope flag is stale even though the handoff's Next Steps are current. In this session, "File.Name.RawEncoding is out of scope" became stale the moment the user asked "is the #if necessary?" and I had to answer "only because RawEncoding is shaped this way." The scope flag presupposed RawEncoding was correct; it wasn't.

**The rule-citation-as-cover pattern.** I cited `[PLAT-ARCH-008a]` to defend the `#if`. The citation was *accurate*: the exception applies, the four conditions hold, File.Name has domain authority. But I used the citation to *conclude the question* rather than to *structure the analysis*. The right use of `[PLAT-ARCH-008a]`: "the exception permits this `#if` to exist, but does this `#if` need to exist?" is a separate question. I collapsed two questions into one. Pattern: when a `[RULE-ID]` answers "is X allowed?", always check whether the user's question was "is X necessary?" These are adjacent but different, and the rule only speaks to the first.

**The iterative-at-wrong-level pattern.** Three iterations, each locally correct, each stepping one level back up the abstraction hierarchy: mechanism → code quality → type shape. The cue I missed: the repeated iteration itself. When two back-to-back corrections from different sources (supervisor, then user) both move the fix *up* a level, the next question is not "is the third level correct?" but "was the initial framing wrong?" The initial framing here was "fix a NUL leak in consumer code." The actual framing — visible in retrospect — was "File.Name doesn't adopt ecosystem vocabulary." The bug was a symptom of the framing gap. Session-end check: count iteration levels; if ≥2 corrections moved the fix upstream, re-examine the original problem statement.

**The supervisor-as-memory-prosthetic pattern.** The supervisor caught a memory-consultation gap, not a knowledge gap. The memory `feedback_no_unsafe_api_surface` existed; I didn't check it. The supervisor check reads my memory better than I do in-session, because the supervisor runs a focused review pass while I'm mid-flow in execution. This suggests a workflow property: **post-commit, pre-push, scan feedback/* memory for adjacent rules to the commit's change class.** A "was there a memory about [unsafe | concurrency | ownership | typed throws | ...] I should have applied?" checklist would close the supervisor's current catch surface without needing the supervisor.

**What worked at the pattern level.** Both upward corrections (supervisor, user) arrived via *reframing*, not *refining*. "Can this be safe?" is a reframe of "how do I apply this unsafe pattern?" "Is there a solved problem here?" is a reframe of "is this `#if` necessary?" Neither correction accepted the current problem frame. I accepted the current problem frame at every step. The asymmetric skill here is *frame-challenge* vs *answer-optimization*; I defaulted to the latter, the reviewers defaulted to the former, and the latter is not sufficient on its own.

**Cost ratio and memory reach.** The supervisor-catch + user-catch together added maybe 40 minutes of conversation and three commit iterations (one landed, one superseded-in-working-tree, one landed on top). The first-principled shape — skip Iteration 1+2, go directly to the refactor — would have taken ~15 minutes once I had the Explore agent's report. The missing step was "before executing the handoff, grep the canonical ecosystem doc" — which is the same lesson as the prior same-day reflection's action item 1 (writer-side `[HANDOFF-013a]`). *Reader*-side grep also applies: when executing a handoff, scan the referenced research docs before coding, not only when the user asks.

## Action Items

- [ ] **[skill]** handoff: Extend `[HANDOFF-016]` with a third staleness category — **scope-flag staleness**. When a handoff marks an item "out of scope" based on an assumption the session later falsifies, the scope flag is stale in the same sense as a stale prescription; re-evaluate with the user before respecting the flag. Cite `File.Name.RawEncoding` "out of scope per handoff" → user-surfaced "actually the root cause" as the case study. Suggest rule text: *"Out-of-scope flags in handoffs are grounded in the author's understanding of the excluded item. When session work reveals the excluded item is incorrect, the flag is stale; verify with the user before treating the exclusion as binding."*

- [ ] **[skill]** implementation: Add a named anti-pattern — **dead-case-per-platform enum**. Shape: a public enum with N unconditional cases where, on any given runtime platform, only 1 case is ever constructed from real data. Signal: consumers `switch` on the enum with a dead branch per platform, or the construction site has an `#if` picking the case. Fix: replace with the ecosystem's existing platform-conditional typealias (`Path.Char`, `String.Char`) for storage, add a local `Encoding` typealias (`UTF8`/`UTF16`) for decoder calls. Cite `File.Name.RawEncoding` → `[Path.Char]` as case study. Red flag: if an enum's case count equals the ecosystem's supported platform count and each case is unconditional, check whether `Path.Char`/`String.Char` already carries the distinction.

- [ ] **[skill]** reflect-session or handoff: Add a **post-commit memory scan** step — before reporting a task as complete, grep `feedback_*.md` memory files for adjacent rules to the commit's change class (unsafe, ownership, concurrency, typed throws, Sendable, …). Would have caught the Iteration 1 `unsafe` regression without needing the supervisor. Rationale: supervisors are scarce; memory scans are cheap. This closes the supervisor-as-prosthetic gap observed in this session.
