---
date: 2026-07-08
session_objective: Land layout-render decomposition Wave 1 and port swift-webpage from coenttb to the institute stack; diagnose the SwiftPM build livelock that blocked it
packages:
  - swift-webpage
  - swift-css
  - swift-css-html-render
  - swift-css-html-layout-render
  - swift-incits-4-1986
status: pending
---

# SwiftPM Identity-Collision Livelock, and a Fan-Out That Tore a File

## What Happened

**Layout-render decomposition Wave 1 landed.** `swift-css-html-layout-render` `bb9170b` (new package — **no git remote at all**, so consumers resolve it purely through the local mirror entry), `swift-css-html-render` `f0904f6` (held, `ahead=1`), and `swift-css` `6aef222` on `main` (held, `main` 1 ahead of `origin/main`). The swift-css commit was landed through a **git worktree**, because that repo's working tree sits on the windows arc's `windows/no-any-htmlview` branch and must not be disturbed.

**swift-webpage port.** Swapped pointfree `swift-dependencies` → `swift-foundations/swift-dependencies` (product identity `"swift-dependencies"` is unchanged, so the target dep line needed no edit). `Button.swift` moved to static theming (`HTMLColor.theme.*`) — institute theming is static/TaskLocal, not `@Dependency`-injected. `Halftone.swift`: `DependencyKey` → `Dependency.Key`, `DependencyValues` → `Dependency.Values`.

**Then the build wedged**: 99% CPU, **zero** `swift-frontend` processes, 13+ minutes, no artifacts, non-terminating. Four hypotheses were raised and empirically refuted:

| Hypothesis | Refutation |
|---|---|
| swift-syntax macro expansion | institute Dependencies has no swift-syntax; wedge persisted after the swap |
| Intrinsic graph-size quadratic | (later shown to be the *misreading*, see below) |
| Broken SwiftPM mirrors | audited all 393 entries: 0 duplicate / missing / ambiguous |
| Slow dependency resolution | `swift package resolve` = **7s** |

The principal supplied the frame that cracked it: *"perhaps coenttb/swift-translating and/or swift-foundations/swift-translating not fully migrated? using both is an issue (same for other same name modules/packages)."* A dependency-URL-**declaration** audit (not a checkout audit) found `swift-incits-4-1986` declared in swift-webpage **without** `.git` (+ `from:"0.0.1"`), while the mirror and every other consumer use the `.git` form (+ `branch:"main"`). SwiftPM mirror matching is **exact-URL**, so the non-`.git` spelling stayed a raw GitHub URL: one identity reachable via *both* a raw URL and a local path → non-terminating consolidation walk in `findAllTransitiveDependencies` / `createResolvedPackages`. This is precisely **[PKG-DEP-002]**.

One-line fix. A cold build (`rm -rf .build`) then re-cloned 168 packages, compiled the **full graph (1468/1624 steps)**, and reached swift-webpage's own module in ~231s — where it surfaced **4338 ordinary §Swap-2 compile errors across 14 files**. Those errors had always been there; the livelock had simply never let compilation begin. Fixing the livelock is what made them *visible*.

**The §Swap-2 fan-out.** A workflow dispatched 14 parallel transform agents (edit-only; builds serialized separately per [PKG-BUILD-009]) plus a serial build-and-fix loop. **13 of 15 agents died on a weekly usage limit.** Two completed (`Alert`, `CalloutModule`); the verify build never ran. Cross-checking the workflow **journal** (belief: `swap2:Halftone` FAILED) against **file mtimes** (state: `Halftone.swift` written *after* workflow launch) surfaced a **torn file** — an agent died between edits, leaving a half-applied mechanical transform.

**Close-out.** swift-webpage checkpointed at `999e968` (pushed, private, tree clean), honestly labelled NOT GREEN with the torn file flagged. Handoff `HANDOFF-swift-webpage-swap2-port.md` + 14 preserved per-file error digests committed as Workspace `95521cb9` (pushed). Explicit per-file `git add` kept the concurrently-running lint arc's in-flight files out of the commit.

**Guards ([REFL-009] step 0)**: `check-memory-corpus.sh` → OK (0 topic files). `check-handoffs.sh` → **61 > 40 WIP cap**, the documented-red state per the 2026-07-06 cap ruling (drain per-arc at close; do not re-triage to force the number). I verified by non-destructive probe that the guard counts **top-level `*.md` at `-maxdepth 1`**: my 14 `.txt` digests live in a subdirectory stash and are correctly *excluded*. My net contribution to the cap is exactly **+1** (the handoff itself).

**HANDOFF scan: 61 live files; 0 deleted, 1 authored-and-left, 2 clusters in-flight no-touch, remainder out-of-authority.**

| File | Outcome |
|---|---|
| `HANDOFF-swift-webpage-swap2-port.md` | authored this session; fresh dispatch, all Next Steps pending → **left**, no annotation |
| `HANDOFF-repotraffic-w4-execution.md` | modified by another session; parent arc is in-flight → **no-touch** per [REFL-009a] |
| `HANDOFF-opus-remediation-arc.md`, `HANDOFF-lint-arc-endgame.md`, `lint-arc-artifacts/*` | lint arc actively executing (its builds were running during this session) → **no-touch** per [REFL-009a] |
| remaining ~57 | outside this session's cleanup authority → untouched, unannotated |

## What Worked and What Didn't

**Worked.** The git-worktree maneuver landed swift-css's re-export on `main` with zero disturbance to a parallel arc's working tree. Each hypothesis was killed with a cheap primary-source probe rather than argument. The **journal-vs-mtime cross-check** caught the torn file — the journal recorded the agent's *outcome*, the mtime recorded the file's *state*, and the disagreement was the finding. The 14 error digests were lifted out of the session scratchpad before it evaporated. Explicit per-file `git add` ([REFL-016], [HANDOFF-021]) kept a concurrently-active arc's files uncommitted.

**Didn't.**

- **I promoted a symptom-suppressor to a causal theory.** A warm-`.build` probe terminated the plan phase in ~15s. I wrote *"It is a terminating quadratic, NOT a livelock"* and was prepared to codify "keep `.build` warm" as the remedy. The warm cache **short-circuits the very consolidation walk that hangs**. The observation was true; the inference was backwards.
- **I audited the wrong artifact.** I searched `Package(name:)` across `.build/checkouts/` for duplicate identities. Checkouts are the *output* of SwiftPM's identity dedup — by construction one directory per identity. A collision between two URL *spellings* of one identity **cannot appear there**. The audit was structurally incapable of finding the defect it was aimed at, and I did not notice.
- A `grep -m1 'name:'` inside that audit matched *product* names, manufacturing false collisions ("CSS Standard") that then had to be disproved — rigor spent inside the wrong frame.
- **A zsh no-op trap fired again.** `comp=$(grep -c 'Compiling' "$log" || echo 0)` yields `"0\n0"`, which `!= "0"` → the watcher falsely announced "plan terminated," and I acted on the false positive. This is the documented [REFL-012] no-op-check class, **recurring**.
- **I fanned out 14 file-mutating agents with no resource pre-check.** 13 died mid-flight. The cost was not the wasted tokens — it was the **torn file**.
- **I never A/B-isolated the fix.** Reverting the `.git` alignment to confirm the livelock returns would have taken minutes. The causal claim remains un-falsified. I recorded the caveat in the commit and the handoff rather than launder it.
- I announced *"FIXED — decisively"* while the build was still running. It survived scrutiny (the livelock *was* gone; the later exit-1 was a different, expected failure), but the declaration preceded the evidence that justified it.

## Patterns and Root Causes

**1. When hunting a fault *inside* a normalizer, only its pre-image is admissible evidence.** SwiftPM maps URL → identity, then dedups. The defect lived in the *many-to-one mapping*; I searched the *one*. Every normalization — dedup, interning, canonicalization, mirror rewriting, symbol resolution — **destroys exactly the evidence of a collision at its input**. Checkout dirs, resolved graphs, `Package.resolved`: all post-image, all blind by construction. The pre-image was the set of `.package(url:)` declarations — a ten-second grep I never ran, because I wasn't in a frame that made it meaningful.

**2. A green obtained by *removing* the suspect stage is a pointer *at* that stage — I inverted its meaning.** Warm `.build` skipped the plan walk and the hang vanished. The correct reading: "the workaround bypasses the step under suspicion, therefore it tells me nothing about that step's complexity, and in fact **localizes** the fault to it." I read it instead as evidence about the step's asymptotics. This is the sibling of [REFL-011]'s tool-reach extension: the warm-`.build` "green" **under-reached** the claim "planning terminates." A workaround's success is evidence about the workaround.

**3. Frame-generation, not evidence-collection, was the bottleneck — and I kept collecting.** All four refutations were methodologically sound and all four were aimed by a frame ("the graph is big / the tooling is broken") that could not contain the answer. The principal's one sentence — *an ecosystem mid-migration has the same package under two identities* — produced the answer in a single grep. The lesson to internalize: **when N independent probes all come back clean, that is not "the mystery deepens"; it is strong evidence the frame is wrong.** The next move is to enumerate alternative frames, not to run probe N+1. I ran probes 2, 3, and 4 after probe 1 came back clean.

**4. A rule whose detector cannot detect its own failure mode will be rediscovered by hand, forever.** [PKG-DEP-002] *already documented this exact livelock*. The skill was right. But its audit procedure (`grep -r 'name:'` for duplicate `Package(name:)`) is blind to `.git`/non-`.git` URL-spelling splits — which is *the* way the collision arises in a mirrored workspace. The rule named the disease and prescribed a test for a different one. This is worse than a missing rule: **the guard's existence manufactured false assurance** ("I audited for identity collisions; clean"). Guards must be validated against the failure they name.

**5. An orchestrator's record of what happened is a *belief*; the filesystem is the *state*.** [REFL-012] says verify loop counters against state. The generalization: any journal, any agent's self-report, any success/failure tally is belief. Trusting the journal alone would have left `Halftone.swift` recorded as untouched; trusting the agents' summaries alone would have recorded it complete. Only the (journal outcome × file mtime) cross-product exposed the tear. And a **half-applied mechanical transform is more dangerous than an unapplied one — it looks done.**

**6. Fan-out over shared mutable state needs a budget pre-check or per-item atomicity.** I honored edit-zone non-overlap ([SUPER-036]) and serialized builds ([PKG-BUILD-009]) — the design was correct on the two axes the skills taught me to watch. The axis I missed, **resource exhaustion mid-flight**, produces precisely the damage those two rules do not cover: a partial transform *inside* a single file's edit zone, where non-overlap guarantees nothing.

## Action Items

- [ ] **[skill]** swift-package: amend [PKG-DEP-002]'s detection procedure. The `grep -r 'name:'` duplicate-`Package(name:)` audit is structurally blind to URL-spelling identity splits (it inspects the post-dedup image). Replace/augment with: group every closure `.package(url:)` **declaration** by computed identity (last path component, minus `.git`, lowercased); flag any identity spelled ≥2 ways, or where a raw-URL ref coexists with a mirror-redirected-to-local ref. Cite the `swift-incits-4-1986` incident.
- [ ] **[skill]** supervise: add a post-run reconciliation step for file-mutating fan-outs — cross-check each agent's journal outcome against its target file's mtime to detect **torn files** left by mid-flight agent death (quota / API error / timeout) — and require a resource-budget pre-check before dispatching a mutating fan-out. [SUPER-036] edit-zone non-overlap does not cover a partial transform *within* an edit zone.
- [ ] **[skill]** issue-investigation: codify two coupled diagnostic rules — (a) "a workaround that suppresses the symptom is evidence about the *workaround*; a green obtained by removing the suspect stage **localizes** the fault to that stage rather than exonerating it"; (b) "when the suspected fault is inside a normalizer (dedup / canonicalization / mirror-rewrite), only the normalizer's **pre-image** is admissible evidence — its outputs have already erased the collision." Provenance: the warm-`.build` "terminating quadratic" misread and the `.build/checkouts/` audit for a pre-dedup defect.
