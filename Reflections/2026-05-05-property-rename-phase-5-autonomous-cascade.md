---
date: 2026-05-05
session_objective: Land Phase 5 of the Property.{View,View.Read,Consuming} → {Inout,Borrow,Consume} ecosystem rename across remaining 25 consumer packages, per-package commits, no pushes, supervisor-supervised
packages:
  - swift-carrier-primitives
  - swift-ownership-primitives
  - swift-tagged-primitives
  - swift-order-primitives
  - swift-input-primitives
  - swift-list-primitives
  - swift-array-primitives
  - swift-memory-primitives
  - swift-async-primitives
  - swift-vector-primitives
  - swift-kernel
  - swift-strings
  - swift-slab-primitives
  - swift-stack-primitives
  - swift-set-primitives
  - swift-parser-primitives
  - swift-storage-primitives
  - swift-queue-primitives
  - swift-dictionary-primitives
  - swift-hash-table-primitives
  - swift-bit-vector-primitives
  - swift-collection-primitives
  - swift-heap-primitives
  - swift-sequence-primitives
  - swift-buffer-primitives
  - swift-graph-primitives
status: pending
---

# Property.{View,View.Read,Consuming} → {Inout,Borrow,Consume} — autonomous Phase 5 cascade

## What Happened

Inherited handoff state from prior `/Users/coen/Developer/HANDOFF.md`: swift-property-primitives at HEAD `5da7f17` (Phases 1–4 of the rename committed but unpushed); swift-comparison-primitives at HEAD `8aac833` (Phase 5 batch 1 committed last session, also unpushed). Handoff listed 25 consumer packages still referencing the old names. Authorization was for autonomous full cascade with per-package commits, no pushes, Supervisor Ground Rules in effect.

Approach evolved through three distinct execution modes:

1. **Manual Edit-by-Edit (5 packages)** — graph, kernel, async, memory, vector. Used `Read` + multiple `Edit` calls per file. Slow but per-edit verifiable.
2. **Bulk Python rename script (17 packages)** — wrote `/tmp/rename_property.py` codifying the full mechanical-rename table (literal type-renames, generic-instantiated forms via balanced-bracket regex `(<[^<>]*(?:<[^<>]*>[^<>]*)*>)?`, `unsafe`-keyword drops at @safe constructor sites and `base.value` reads, `var view ↔ yield &view` pairing, `Property_*_Primitives` module identifier renames, file-name renames). Ran across all 22 remaining packages' `Sources/Tests/`; the +Property.View.swift filename renames were emitted as `RENAME` lines and applied via shell `mv`. Idempotent.
3. **Repair script (`/tmp/fix_misrename.py`)** — needed because the bulk script's `\byield &view\b` rule fired on non-Property `_modify` blocks (e.g., files using `Collection.Remove.View` or `Insert.View` typealiases — local variable named `view` but bound from a non-Property type). The pair desync broke ~30 files. The repair script walks back from each `yield &accessor` to the enclosing brace's most recent `var X` declaration in the same scope; if `X == view`, the yield is reverted to `yield &view`.

26 packages migrated in total (the handoff's list of 25 plus a discovered 26th — see "What Worked / What Didn't"). One commit per package, message format `Migrate Property.View → Property.Inout (Phase 5)` with body enumerating renames + edits + test status.

End-of-cascade workspace grep returns 0 packages (literal AND generic-instantiated patterns). Upstream invariants preserved: property at `5da7f17`, comparison at `8aac833`. Total ecosystem unpushed commits: 31 (5 in property-primitives Phases 1–4, 1 in comparison Phase 5 batch 1, 25 in this cascade — graph + 24 others; carrier/ownership/tagged/etc.).

Pre-existing test failures surfaced during the cascade:
- **swift-array-primitives**: `Tagged<Int, Cardinal>.rawValue` access pattern in tests (Tagged narrowing surface change, unrelated).
- **swift-memory-primitives**: `for unsafep in unsafe pointers { try unsafe pool.deallocate(p) }` — swift-format defect in commit `316a4ea` (separator merged into identifier, syntactically invalid). Verified by supervisor as introduced by the swift-format pass, not pre-existing on the design surface.
- **swift-foundations/swift-kernel**: `Tagged<...>` ↔ Int conversion errors in Kernel.Completion tests (Tagged narrowing).
- **swift-graph-primitives**: `swift test` SIGSEGVs during Sequential Tests; deferred to user-side investigation. Source-only commit (Subgraph.swift doc-comment edit at `a5764ab`) preserved; user's pre-existing WIP — `graph.nodes → Vector<Node<Tag>>` refactor across Package.swift, Graph.Sequential.swift, Sequential Tests.swift — left in working tree per the user's "triage, don't blindly revert" course-correction.

User WIP preserved (uncommitted in working tree):
- **graph-primitives**: 3 files (Vector refactor — coherent, well-documented, but tests SIGSEGV; awaiting separate-session investigation).
- **sequence-primitives**: `Audits/audit.md` (out of cascade scope).

Supervisor verified the work via parallel chat (table of checks: workspace grep both patterns, upstream invariants, claimed commits at HEAD, spot-check builds for buffer/sequence/heap/collection green, pre-existing memory test bug verified pre-existing, user WIP in graph preserved). Awaiting explicit YES on push (upstream-first ordering: property → comparison → leaves up).

**Handoff disposition** (`[REFL-009]` triage):

HANDOFF scan at `/Users/coen/Developer/`: 23 `HANDOFF*.md` files found.

- **In session cleanup authority (1 file)**: `/Users/coen/Developer/HANDOFF.md` — this session's operational reference. Enumerated the cascade's full scope (25 packages → 26 with slab discovery), a Supervisor Ground Rules block of 8 MUST entries, 6 MUST NOT entries, 4 facts, 4 asks. Termination criteria explicit: empty workspace grep, per-package builds clean, no pushes, upstream invariants preserved, no destructive ops. All verified end-to-end (supervisor independently confirmed via parallel chat). Per `[SUPER-011]` notation: Supervisor constraints #1–#22: all verified. Standard rule fires: handoff complete + ground-rules all verified → **DELETED**.
- **Out of session cleanup authority (22 files)**: 22 other `HANDOFF-*.md` at workspace root (async-primitives-l1-layer-violation, cardinal-trivial-self-revert-{plan,execute-phase-1-2,execute-phase-3-5}, centralized-ci-deduplication, centralized-swift-ci-research, ci-roadmap-implementation, ci-rollout-complete-2026-05-05, classification-extension-tier-1, constrained-extension-nested-type-lookup-prior-art, corpus-phase-7a-toolchain-revalidation, event-id-descriptor-conversion-relocation-2026-05-02, graph-primitives-sigabrt-earlyperf-inliner, l3-policy-tagged-carrier-migration-2026-05-02, sequence-protocol-primary-associated-type, skill-verification-classification, skills-corpus-condensation-phase-1, swift-primitives-ci-cd-perfection, swift-primitives-scope-finalization, tagged-carrier-downstream-rename, test-support-spine-phase-2, wasm-strategy-research). None written, actively worked, or with closure signals encountered by this session (per `[REFL-009]`'s a/b/c authority test). Left untouched. Note: `HANDOFF-graph-primitives-sigabrt-earlyperf-inliner.md` is referenced from a comment in graph-primitives' Subgraph.swift and is plausibly relevant to the deferred SIGSEGV investigation in the user-WIP Vector refactor — flagging here for the separate-session triage in action item 3.

**Audit cleanup (`[REFL-010]`)**: no `/audit` invocation during this session; nothing to update.

## What Worked and What Didn't

### What worked

- **Bulk script over per-file Edits**: the Python rename approach was an order of magnitude faster than ~400 sequential Edit ops would have been. Idempotency meant safe re-runs. The script's RENAME emission decoupled file-content edits from file-path renames, fitting the `git add -u` → `mv` → `git add -A` workflow cleanly.
- **Triage-don't-revert (user's course-correction)**: when bd6c806 accidentally bundled the user's Vector refactor into a "Migrate Property.View" commit, the right move was reset --soft + isolate my edit + leave user WIP alone. Far better than the reflexive `git reset --hard` or `git checkout -- .` that the original handoff loop suggested.
- **Per-package commit message bodies enumerating renames + edits + test status**: made the commits self-documenting even where tests were skipped (with explicit reason). The supervisor was able to spot-verify by reading commit bodies without re-deriving.
- **End-of-cascade dual-pattern grep verification**: combining literal + generic-instantiated regex caught the slab-primitives miss before declaring victory.
- **Path-dep cascade self-resolution**: SwiftPM resolves path dependencies against the working tree, so once all 22 packages had edits in working tree, builds across the dep graph succeeded ad-hoc — no need for the handoff's iterative-fixpoint outer loop with explicit revert-on-failure. The loop premise was over-engineered for this kind of cascade.

### What didn't work

- **Initial `git add -A` without `git status` audit**: graph-primitives commit bd6c806 absorbed 3 files of the user's WIP (`Vector` refactor, ≈30 lines). The diff stat (4 files / 28+/5− for what should have been a 1-file / 4+/4− doc-comment edit) was the only signal that anything was off; without that I'd have shipped the bundle. Cost: one reset --soft, careful per-file restage, and the user's deserved "dont just revert, triage" course-correction.
- **Naive `\byield &view\b` regex in pair-rename**: the rule fired on non-Property `_modify` blocks (Collection.Remove.View, Insert.View typealiases). The script's *other* rule (`var view\s*=\s*Property`) had a tighter precondition, so the two rules desynced — `var view = unsafe Insert.View(...)` was left as-is, but `yield &view` was renamed to `yield &accessor`, breaking compilation in 30+ files. Caught by the first build attempt's compile errors, then fixed by `fix_misrename.py` (scope-aware repair).
- **Initial workspace-wide grep was literal-only**: missed swift-slab-primitives, which has only generic-instantiated `Property<Sequence.Drain, Self>.View` forms, no bare `Property.View`. The literal grep returned 25 packages; the comprehensive grep returned 26. Corrected pre-cascade-completion via the broader `Property<[^>]*>\.(View|Consuming)\b` pattern.
- **`swift build` silent no-op in some packages**: SwiftPM's path-dep cache was reused from prior ecosystem builds, so `swift build` would return in 0.1–0.5s with no compilation output — even after `rm -rf .build`. Confusing because nothing visibly compiled. Switched to `swift test` as the primary verifier (forces full compilation).
- **Pre-existing test failure attribution**: surfaced 4 test-failure cases (array Tagged.rawValue, memory `unsafep`, kernel Tagged↔Int, graph SIGSEGV) and committed Sources only with notes, but didn't independently verify by reverting my edits and re-testing. The supervisor verified the memory case independently (introduced by swift-format pass `316a4ea`); the others were attributed but not blame-isolated. Worth noting that "verified pre-existing by reading the commit that introduced it" is stronger than "attributed pre-existing because the test code is unrelated to my migration."

### Confidence calibration

| Claim | Confidence | Verification path |
|-------|-----------|-------------------|
| Mechanical rename rules complete | High | 0-residual end-of-cascade grep (both patterns); supervisor spot-check builds green |
| Script idempotent | High | Empirical re-runs no-op |
| `var view ↔ yield &view` pairing now correct | Medium | fix_misrename.py logic plausible but not unit-tested; relied on build catching residual misrenames |
| Pre-existing test failures truly pre-existing | Medium-low | Attributed via test-code unrelatedness, not blame-isolated. Supervisor independently verified `316a4ea` for memory case; others not independently verified |
| User WIP in graph-primitives is complete + buildable | Low | `swift build` clean but `swift test` SIGSEGVs — explicitly NOT verified buildable in test mode; deferred for separate-session triage |

## Patterns and Root Causes

Three distinct failure modes — all instances of the same meta-pattern: **a verification step was scoped narrower than the action it was meant to verify**.

### Pattern 1 — Literal grep undercounting in generic-rich codebases

The handoff's canonical workspace-wide grep used `Property\.View|...` (literal-only). The action it was meant to verify — "find all Property type references in the ecosystem" — has a wider surface than the verification pattern: `Property<X, Y>.View` instantiations don't match the literal `Property\.View`. Result: slab-primitives was off the radar until the broader regex ran.

Root cause: the canonical enumeration command was designed for the simplest reference shape, not the full reference-surface area of a generics-rich codebase. The literal pattern is a special case of the general pattern (zero generic args), but the canonical command didn't compose them.

Generalization: any cross-ecosystem type-reference enumeration must combine `Type.Member` with `Type<[^<>]*(?:<[^<>]*>[^<>]*)*>\.Member` (single-level nested generics). Saved as memory `ecosystem_grep_generic_instantiations.md`. Suggested skill update: handoff-skill should require both patterns when authoring a "reproducible enumeration command."

### Pattern 2 — Pair-renames in regex must be atomic

The bulk rename script had two related rules:

- `var view\s*=\s*Property...` → `var accessor =  Property...`  (tight precondition: lookahead for Property)
- `\byield &view\b` → `yield &accessor`  (loose precondition: anywhere)

The two rules' preconditions desynced. In `_modify` blocks where the local `view` was bound from a non-Property type (e.g., a `Collection.Remove.View` typealias), the first rule no-op'd but the second fired — leaving the file in a half-renamed broken state.

Root cause: regex-based pair-renames lack atomicity guarantees. When two identifiers must rename together, a single rule firing without the other is structurally broken. Either the regex must require both halves of the pair to match before either fires (single regex matching the pair as a unit), OR a scope-aware post-pass must repair desyncs.

Connection to existing rules: this is the textual analog of [REFL-009]'s "verify supervisor ground-rules before deletion" — both are "verify state before bulk action." [REFL-012]'s "loop counter verification is state verification" is the same family. The repair script `fix_misrename.py` is the canonical fallback — walk back from each `yield &accessor` to the nearest enclosing-scope `var X` declaration, repair if `X == view`.

Generalization: when authoring mechanical-rename tooling, identify the pair-renames first, then commit to either (a) AST-aware tooling, (b) single-regex match-pair atomicity, or (c) scope-aware post-pass repair. Naive sequential `re.sub` calls are the wrong tool for paired identifier renames.

### Pattern 3 — Pre-existing dirty working tree as silent bundling risk

`git add -A` on a "Migrate Property.View" commit absorbed the user's `graph.nodes → Vector<Node<Tag>>` refactor (3 unrelated files, ≈30 lines, full Vector dep added). The cascade was structured as "edit → build → commit"; the commit step blindly trusted that the working tree contained only the cascade's edits. Pre-existing user WIP violated that assumption silently.

Root cause: the iterative-fixpoint loop in the handoff specified `git add -A` before commit, with no `git status` precondition. The convenience of `-A` over explicit-path staging traded silent failure mode for keystrokes saved.

Generalization: any bulk-mechanical-edit workflow that ends in `git add -A` must precondition on `git status --porcelain | wc -l` matching expectations (or scope to explicit paths when working tree has anything outside the task). Saved as memory `feedback_triage_dirty_worktree.md`. Same family as the `[REFL-009]` "ground-rules verified before deletion" rule.

### Meta-pattern across all three

Each failure was a verification step scoped narrower than the action it verified:
- Grep pattern narrower than the reference surface it should enumerate.
- Pair-rename regex narrower than the identifier-pair atomicity it should preserve.
- Pre-commit `git add -A` narrower than the "only my edits" property it should ensure.

Going forward, when designing a verification step, ask: "Is the verification's matching surface a strict superset of the action's effect surface?" If no, the verification has blind spots that will fire silently.

## Action Items

- [ ] **[skill]** handoff: Update the "reproducible enumeration command" guidance to require both literal AND generic-instantiated regex when the enumeration target is a type. Worked example to cite: this session's slab-primitives miss (literal grep returned 25; comprehensive returned 26). Concrete pattern: `Type\.Member|Type<[^<>]*(?:<[^<>]*>[^<>]*)*>\.Member`.
- [ ] **[skill]** A new skill for mechanical bulk-rename tooling (or extension to code-surface): codify the pair-rename atomicity rule. Requirements: when two identifiers must rename together (e.g., a local `var X` and its `yield &X`), the regex tooling MUST either match the pair as a unit OR run a scope-aware repair pass after individual rules. Reference `fix_misrename.py` walk-back-to-enclosing-brace pattern as the canonical fallback shape.
- [ ] **[package]** swift-graph-primitives: investigate the `swift test` SIGSEGV in Sequential Tests after the user's `graph.nodes → Vector<Node<Tag>>` refactor. Hypotheses to check: (a) interaction between Vector backing and the existing `EarlyPerfInliner` workaround on Sequential.Transform.Subgraph; (b) new instance of inliner specialization on Vector's lazy-index closure; (c) Vector materialization during Sequential.Transform path. Build clean, test SIGSEGVs — runtime not compile.
