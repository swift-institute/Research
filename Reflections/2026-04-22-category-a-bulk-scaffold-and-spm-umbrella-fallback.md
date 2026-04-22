---
date: 2026-04-22
session_objective: Continue HANDOFF.md's Workstream B — Category A DocC-catalog scaffolding, then (per principal mid-session review) Category D generator fix via SPM dump-package fallback and Category B Documentation.docc rename batch.
packages:
  - swift-primitives
  - swift-standards
  - swift-foundations
  - swift-institute/Scripts
status: pending
---

# Category A DocC bulk scaffold + SPM umbrella-name fallback for Category D unblock

## What Happened

Resumed HANDOFF.md / HANDOFF-package-refactor.md as a Workstream B execution session. Verified the prior-session state (all 7 referenced commits present: `d0e819f`, `e184b7c`, `62380f5`, `f9b8d11`, `c080d2e`, `9ad3667`, `0fccdaa`; parallel standards-org-migration session had landed Phase 2 prep at `62380f5` only).

**Baseline generator state** (sync-ci-callers.sh --dry-run): 285 total candidates, 7 would-migrate, 210 needs-refactor, 68 skipped.

**Phase 1 — Category A bulk scaffold**:
- Wrote `swift-institute/Scripts/scaffold-docc-catalog.sh` mirroring the sync-*.sh idiom (--dry-run, --only, preflight: not-main / uncommitted-sources / no-git; per-sub-repo commit; never pushes).
- Umbrella inference replicated from sync-ci-callers.sh byte-for-byte (grep `products:` block → case-insensitive slug-title match → fallback non-reserved library name).
- Pilot cadence: single package (`swift-array-primitives`) → `swift-b*` batch (10 packages) → full bulk-apply (185 more). 196 sub-repo commits with message `docs: scaffold umbrella DocC catalog`.
- Each catalog: `Sources/<Umbrella>/<Umbrella>.docc/<Umbrella>.md` with [DOC-021] baseline (module-identifier H1 with underscores, `@Metadata { @DisplayName, @TitleHeading }`, placeholder paragraph, `## Topics` stub). Layer heading varies by org (`Swift Primitives` / `Swift Standards` / `Swift Foundations`).
- Post-phase state: 203 would-migrate / 14 needs-refactor.

**Principal review arrived mid-session**. Principal acknowledged clean execution, flagged 5 concerns, and dispatched two follow-ups to this session: (a) implement `resolve_umbrella_via_spm()` in sync-ci-callers.sh to unblock 12 Category D symbol-ref packages without Package.swift rewrites; (b) write `Scripts/rename-docc-catalogs.sh` for Category B Documentation.docc → `<Umbrella>.docc` renames. Principal explicitly scoped out: no pushes, no live CI migration, no touching the 2 WIP-skipped packages, no placeholder-content pass.

**Phase 2 — Category D generator fix**:
- Probed `swift package dump-package` JSON on `swift-translating` to confirm SPM resolves symbol-ref product names. Confirmed: first library product = `Translating`, matches slug.
- Refactored sync-ci-callers.sh: extracted `match_umbrella_from_names()` as shared helper; added `lib_names_spm()` (python3 JSON parse of `swift package dump-package`); `umbrella_name()` now tries grep-based `lib_names` first, falls back to SPM on empty. Invoked only when grep fails so the common path stays fast.
- Realized mid-fix that the generator change alone only unblocks `swift-translating` (which had pre-existing `Documentation.docc`). The other 11 Category D packages (css, html, pdf, svg families + copy-on-write) lack DocC entirely and are blocked by the earlier `no DocC catalog under Sources/` check. To unblock them, `scaffold-docc-catalog.sh` also needed the SPM fallback.
- Applied identical refactor to `scaffold-docc-catalog.sh`. Re-ran scaffold on the 11 Category D packages — all succeeded. SPM's resolved library names for some still reflect gerund-form naming (e.g., `CSS HTML Rendering` in `swift-css-html-render`); catalogs reflect that current state and will re-align naturally when a future noun-form rename pass touches the libraries.

**Phase 3 — Category B rename batch**:
- Wrote `Scripts/rename-docc-catalogs.sh` following the sync-*.sh idiom. Includes the same umbrella inference (grep + SPM fallback).
- Survey of the ecosystem found 6 sub-package `Documentation.docc` directories (not 19 as the principal's review had estimated). The `19` figure was the `already had catalog` counter from the Phase 1 post-bulk dry-run, which inherited 11 catalogs the pilot had just freshly scaffolded — a count-inheritance artifact, not a real refactor queue.
- 5 clean renames: `swift-binary-primitives`, `swift-structured-queries-primitives`, `swift-postgresql-standard`, `swift-kernel`, `swift-translating`. 1 correctly-flagged mismatch: `swift-file-system` (catalog at `Sources/File System Core/`, umbrella is `File System` — relocation, not rename; left for principal's manual pass).

**Final state**:
- Generator: 215 would-migrate / 2 needs-refactor. The 2 are `swift-format-primitives` and `swift-standard-library-extensions` (both have uncommitted WIP in Sources/, correctly skipped by all three scripts' preflight).
- Scripts repo: `5ae7bc6` (scaffold-docc-catalog.sh) + `1987462` (SPM fallback + rename-docc-catalogs.sh).
- 196 Category A + 11 Category D + 5 Category B sub-repo commits, all local, ahead of origin.
- Three superrepos show submodule-pointer `M` statuses, not pushed.

Principal subsequently confirmed the floor state and directed a standby: do not run live CI migration, do not push, do not expand.

## What Worked and What Didn't

**Worked**:
- **Pilot-then-batch cadence**. Single package → `swift-b*` batch → full bulk caught nothing in bulk that the small batch didn't also surface. The task's homogeneity makes this cadence cheap and high-confidence; not always the case but good here.
- **Replicating sync-*.sh idiom verbatim**. The preflight states (`not-main`, `uncommitted-sources`, `no-git`), `--dry-run`/`--only` conventions, per-sub-repo commits, "never pushes" invariant all came from the existing idiom. No friction integrating the new scripts; they report with the same vocabulary as siblings.
- **Verifying state before acting**. The handoff's 7-commit list was fully confirmed before any new work landed. No time spent on stale premises.
- **Dry-run → sync-ci-callers.sh --dry-run feedback loop**. After each batch I re-ran the generator to confirm the would-migrate count climbed and needs-refactor fell by the expected amount. Transitions were always monotonic and as predicted; any surprise would have been caught immediately.

**Didn't work first time**:
- **Forgot that generator fix alone wasn't enough for Category D**. When the principal asked for resolve_umbrella_via_spm() in sync-ci-callers.sh, I initially implemented it there only. Half-way through testing I realized 11 of the 12 Category D packages lack DocC entirely, which means they fail the generator's `find_docc_catalog` check *before* umbrella_name is ever called. Unblocking them required the SPM fallback to also be in scaffold-docc-catalog.sh. Recovery was cheap (10 lines duplicated), but the gap was real — a completeness-of-cascade failure.
- **Triple duplication of umbrella inference logic**. By session end three scripts (sync-ci-callers, scaffold-docc-catalog, rename-docc-catalogs) carry byte-identical `lib_names`, `lib_names_spm`, `match_umbrella_from_names`, and `umbrella_name` functions. Copy-paste kept them independent but creates a drift hazard — any future tweak must touch all three or silently miscategorize. Acceptable at n=3; uncomfortable approaching n=5.
- **Principal's `19` Category B estimate vs actual `6`**. Not my failure — but the 13× overestimate is a symptom of a real phenomenon (count-inheritance) that could have led me to scope a more ceremonial rename batch. The fact that the dry-run surfaced the actual 6 before I wrote the rename script meant the overestimate cost nothing; had I sized the script to 19 it would have been measurable waste.

**Confidence was low on**: whether the 11 gerund-form library names (`CSS HTML Rendering`, etc.) would round-trip cleanly through the generator. They do — the generator takes whatever SPM reports and the thin-caller templates are name-agnostic. But that path wasn't on a prior-session's verified-green checklist; I verified it live.

## Patterns and Root Causes

**Cascade completeness**: The session exhibited a "fix the generator, forget the scaffolder" failure mode. The Category D unblock has two stages: (1) if the package has DocC, generator must be able to infer umbrella; (2) if the package lacks DocC, scaffolder must be able to run. Stage 1's fix looked complete in isolation; stage 2's dependency on the same inference change was invisible until I asked "does this actually move the 11 no-DocC Category D packages to would-migrate?" It doesn't, because they're still blocked at stage 0.

This is a specific case of a general pattern: **a fix at one checkpoint only unblocks work at that checkpoint**. Tools with layered gates (preflight → DocC presence → umbrella inference) must be thought about as a pipeline where each earlier gate silently filters out any work the later gates could handle. "We fixed umbrella_name" and "Category D packages are now would-migrate" are not equivalent statements. The way to catch this failure at write-time is to trace the target cases backward through the pipeline: "for Category D package X, which gate fails today?" — the answer for 11 of 12 was the DocC gate, not the umbrella gate.

**Two-tool symmetry is load-bearing, not decorative**: The scaffold script and the generator must agree on umbrella identity or they can silently disagree about what "needs refactor" means. A package where scaffold says "I can handle it" but generator says "umbrella not inferable" (or vice-versa) represents a stuck state invisible from either tool alone. Copy-pasting the inference logic is a correctness investment, not a laziness shortcut — but it stops being reasonable once the inference needs to change in a non-backward-compatible way across 3+ scripts. The question of when to factor into a shared helper is not yet forced; n=3 with identical logic is the comfortable ceiling.

**Count inheritance**: Any metric reported mid-session (`already had catalog: 19`) may include transient session work (the 11 packages the pilot had just scaffolded). A principal reading a summary counter cannot distinguish pre-session vs within-session contributions. This is a species of staleness but not one [HANDOFF-016]'s axes cover directly — it's "metric freshness": a number that was correct at T but changes meaning as session work progresses. Not every metric needs to be handoff-resilient, but when a number is going to be the basis for a scope estimate, pre-session baseline vs current state should be distinguishable.

**The preflight `uncommitted-sources` skip is load-bearing self-protection**. Two packages (swift-format-primitives, swift-standard-library-extensions) had WIP in Sources/. My scripts skipped them correctly. Had the scripts been aggressive (fall through on dirty state, scaffold anyway), the new catalog commit would have been sitting on top of the user's in-progress work. The preflight state names matter — `uncommitted-sources` with a narrow Sources/ scope skip is the right fidelity; a broader "dirty working tree" skip would have unnecessarily skipped packages with dependabot.yml edits in the common case.

## Action Items

- [ ] **[research]** Shared umbrella-inference helper across `sync-*.sh` scripts — is copy-duplication of `lib_names` / `lib_names_spm` / `match_umbrella_from_names` / `umbrella_name` across sync-ci-callers.sh, scaffold-docc-catalog.sh, rename-docc-catalogs.sh sustainable? When does the trend toward 5+ scripts force factoring to `Scripts/_umbrella-inference.sh`? Weigh independence of standalone scripts vs DRY and drift-prevention. Investigate as a `Scripts/`-internal design doc.
- [ ] **[skill]** handoff [HANDOFF-016]: Consider adding a "metric-freshness" sub-axis to the staleness table — counts reported mid-session (`already had catalog: 19`, `needs-refactor: 210`) may mix pre-session baseline with within-session transient state; a principal reviewing such a count cannot distinguish contributions without asking. Might be too narrow for a full axis; consider a single-sentence clarification under "Work staleness" instead.
- [ ] **[package]** swift-institute/Scripts: Add a SCRIPT CONVENTIONS comment (or short README note) to `sync-ci-callers.sh` documenting the cross-script invariant: any future script that classifies packages by umbrella MUST use the same `lib_names` + `lib_names_spm` + `match_umbrella_from_names` logic; diverging causes silent miscategorization between which-packages-I-scaffold vs which-packages-the-generator-migrates.
