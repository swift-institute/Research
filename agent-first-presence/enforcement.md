# Enforcement design for the agent-first authoring standard

Produced 2026-07-30 by the enforcement-design agent. Read-only with respect to GitHub; no file
in the local Institute checkout was modified. Grounded in the actual tooling: the
Workspace CLI sources, swift-linter and its rule packages, the `.github` central validator
fleet and reconciler, the fixture suites, and the canonical skills at
`swift-institute/Skills`.

---

## 0. The real enforcement landscape (what actually exists)

Any predicate catalogue is meaningless without the honest inventory of owners. There are
**five** distinct enforcement hosts today, not the two the first-pass report names.

### 0.1 swift-linter — Swift AST only, by construction

- Engine at `swift-foundations/swift-linter`; rule vocabulary at
  `swift-primitives/swift-linter-primitives`; rule packs at `swift-{primitives,standards,institute}-linter-rules`
  plus `swift-foundations/swift-linter-rules`.
- A rule is a **data value**: `Lint.Rule(id:default:suppression:findings:)` where
  `findings: (borrowing Lint.Source.Parsed, Diagnostic.Severity) -> [Diagnostic.Record]`
  (`Lint.Rule.swift`). `Lint.Source.Parsed` **requires a SwiftSyntax `SourceFileSyntax` tree**
  (`Lint.Source.Parsed.swift`). Rules are pure; no filesystem, network, or API access.
- The walker includes `**/*.swift` only and **explicitly excludes `**/*.docc/**`**
  (`Lint.Source.Walker.swift`). Markdown, READMEs, DocC catalogues, issue bodies, and org
  profiles are all outside its input domain.
- Delivery/receipt model: `workspace lint install` downloads checksum-verified prebuilt
  binaries; the installed build is identified by a **content-addressed composite digest** over
  engine + four rule-pack revisions (`.workspace/lint/MANIFEST.txt`, digest
  `89924760b9b2…f1483` — byte-identical to the activation digest ratified in
  `swift-institute/.github#90`). `workspace lint check` compares that digest against the one CI
  consumes. This is the concrete #90 receipt implementation.
- Fixture model: Swift Testing suites per rule (`Unit` / `Edge Case` / `Integration`), inline
  source-string fixtures, positive (fires, right id/severity/count) and negative (silent)
  controls — e.g. `Lint.Rule.Manifest.BareStringDependency Tests.swift`.
- Fail-closed adjudication is Workspace's, not the engine's: the engine exits 0 with zero rules
  loaded; Workspace adjudicates the always-on summary line and reports `UNMEASURED`, never
  clean, when rules didn't load or no files scanned (Workspace/CLAUDE.md; `Workspace.Lint.*`).
  The sweep enumerates from `Workspace.json`, never a tree walk, and errors on an empty
  materialized population.

### 0.2 The `.github` central validator fleet — the actual "central policy path" for pages

- ~45 Python validators at `swift-institute/.github/.github/scripts/validate-*.py`, bound to
  rule IDs and workflows by `validators-manifest.yaml` ("single source-of-truth for rule-ID ↔
  validator-script ↔ workflow-file binding"), called through the reusable
  `validate-base.yml` with declared `discovery-mode` (single-target / wrapper-host-multi-file /
  per-package-org-sweep).
- **README rules already exist**: `validate-readme.py` implements README-017/026 (universal),
  README-001/003/008/013/016 (family E packages), README-137/138 (process repos),
  README-150/151 (placeholders), README-116 (org profiles). Family routing comes from
  `readme.family` (`A|C|E|F|G`) or `exempt: vendored-upstream` in each repo's
  `metadata.yaml`, schema-enforced by `metadata-schema.json`; an absent block yields
  `README-family-unset` (fail-closed routing).
- **DocC rules already exist**: `validate-docc-structure.py` (DOC-020/021/026/070/071/101) —
  layout, root page, flatness, tutorial refs, and one *content* regex (DOC-101 forbids
  `## Research` / `Status: DECISION` in per-symbol articles). Precedent for content-shape
  predicates over markdown.
- Fixture model: `scripts/tests/fixtures/<rule-id>/{fail,pass,edge}/` repo-shaped fixtures;
  `run.sh` requires every `fail/` fixture to produce a finding, every `pass/`+`edge/` to
  produce none, and **errors on a silent SKIP** (a fixture that no longer resolves to a
  registered validator). `lint-validator-fixtures.yml` runs the suite on every validator edit
  plus weekly — this is the #90 positive/negative/fail-closed model at the CI layer, already
  operational.
- README-164 (README version-currency) is **named in scope comments but unimplemented** — no
  workflow exists.

### 0.3 The GitHub-records reconciler — the host for issue-body predicates

`reconcile-project-invariants.yml` is a scheduled GraphQL reconciler over the ProjectV2 row
(org `swift-institute`, ProjectV2 number 2): report-only plus exactly two ratified idempotent
mutations (#114/#116), one divergence issue found by **title match, never label** (a prior
sweep keyed off a label that never existed and could not fire), dry-run mode, and invariants
including "Goal type only in swift-institute". Any predicate that must read live GitHub
objects (issue bodies, Project titles, issue types) belongs to this family — it is the only
existing owner with API access, scheduling, and a fail-closed reporting convention.

### 0.4 Workspace — generation, enumeration, receipts, local drift checks

- `workspace doctor`: checks end in exactly one of `ok`/`finding`/`unmeasured`/`notApplicable`;
  a check that did not run must never read as one that passed (issue #43 doctrine).
- `workspace package dump-package` exists (`Build.Action.dumpPackage`) — SwiftPM's own
  **evaluated manifest**, the sanctioned no-second-parser route to products/targets/platforms.
- Caution: Workspace already contains a deliberate second *reading* of manifests —
  `Workspace.Dependency.Parser`, a token-level parser strictly for `.package(` declaration
  surgery (compose/restore). Any README generation must consume `dump-package`, never grow
  this tokenizer into a product/platform parser.
- Byte-compare drift precedent already exists twice: `sync` re-renders
  `institute.xcworkspace` and byte-compares before writing; `workspace build` re-renders the
  scheme from manifests and **refuses to run on mismatch**. This is exactly the generated-block
  drift-check shape to reuse.
- Receipt precedent: lint `MANIFEST.txt` (content digest + component revisions + built-at)
  and the installation receipt in `Workspace.Installation.swift`. #94 specifies the general
  form (canonical JSON, sorted records, hashed after canonical serialization and independent
  re-read) but **no generic receipt type exists in Workspace yet**.
- Markdown-validation precedent inside Workspace: the `Skill Validation` target
  (`Skill.Document.swift`) parses SKILL.md frontmatter with typed errors and a 500-line cap.

### 0.5 Issue forms and skills

- Forms propagated from `swift-institute/.github`: `bug.yml`, `change.yml`,
  `documentation.yml`. **There is no Goal form**; Goal bodies follow a de-facto grammar
  (#79/#90: Objective / Owner and scope / Activation / Gates and derived constraints / Native
  relationships / Completion; #94 deviates with extra sections). Forms shape authoring but
  GitHub never re-validates edits — post-edit conformance needs the reconciler.
- Skills: `documentation/SKILL.md` + companions `readmes.md`, `docc.md`; `github/SKILL.md`.
  The governing frame is `Internal/ENFORCEABILITY-TAXONOMY-2026-07-28.md`: every normative
  line is **decidable / judgeable / open**; judgeable rules get a **decidable shell**
  (judgment recorded in a fixed place and form, and the recording is checked); voice must
  disclose what is and is not checked. `readmes.md` already carries the required "Where the
  check and the text disagree" section — any new predicate must keep that section truthful.
- Standing tension to name: `Internal/CLAUDE.md` rules "no new Python or shell automation"
  for Institute tooling, while the central validator fleet is Python. The fleet predates the
  ruling and is `.github`-owned; a Swift path exists (`Tools/RepositoryPolicy`, and issue #80
  routes to "central repository-policy validation"). New markdown predicates therefore face a
  host decision: extend the Python fleet (cheapest, continues an established `.github`
  pattern) vs. grow the Swift `RepositoryPolicy` tool (aligned with Full-Swift direction).
  This is an **open** choice in taxonomy terms and needs a ruling, not a guess.

---

## 1. Predicate catalogue

Legend — Decidability per the enforceability taxonomy; FP = false-positive risk; fixtures per
the #90 model (positive = must fire, negative = must stay silent, fail-closed = the check must
report unmeasured/error rather than clean when it could not measure).

### P1. Display-name Project references ("admitted to Institute Work")

- **Decidable?** Decidable shell over a judgeable core. Fully mechanical: flag occurrences of
  any *current* ProjectV2 title in an Institute issue body/comment that lack an adjacent
  durable coordinate (`https://github.com/orgs/swift-institute/projects/<N>` or
  "ProjectV2 number <N>"). The gloss form (durable coordinate + parenthetical "currently
  titled…") passes. Whether a given prose mention *needed* to be a reference at all stays
  judgment.
- **Owner:** reconciler family in `swift-institute/.github` (new report section or sibling
  scheduled workflow). **Not swift-linter** (no API access, wrong input domain), not
  Workspace (GitHub records are `.github` control plane per the github skill's routing rule).
- **Detection signature:** GraphQL `organization.projectsV2 { number title }` to resolve the
  live title set (the detector must not hard-code "Institute Work" — the display name is
  itself the volatile fact); then per-body regex for each title, case-sensitive, outside code
  fences, with a same-paragraph window test for `orgs/<org>/projects/<number>` or
  `ProjectV2 number \d+`.
- **FP risk:** medium (generic prose "institute work" in lowercase is excluded by case; quoted
  historical text will fire). Report-only permanently, or report-only until precision is
  measured. Fail-closed: if the title query fails, report "unmeasured", never clean.
- **Fixtures:** scanner unit tests in the fleet's `tests/test-*.py` pattern — positive: bare
  "admitted to Institute Work"; negative: #94's amended gloss and the github-skill sentence
  ("**Institute Work**, `https://github.com/orgs/swift-institute/projects/2`"); fail-closed:
  injected GraphQL failure.

### P2. Manifest restatement in READMEs

Split into a coverage floor and a restatement ceiling; they compose, and generation satisfies
both.

- **Coverage floor** (every user-facing product named at least once): decidable via the
  evaluated manifest; **already owned by open issue #80**, whose text routes it to central
  repository-policy validation with "one authoritative manifest evaluation". Do not create a
  second owner.
- **Restatement ceiling:** decidable **only after generated blocks exist**. Mechanical form:
  (a) generated block between `<!-- workspace:generated:<kind> -->` markers must byte-equal
  the generator's output for the current manifest (drift check, zero FP); (b) deny-list of
  manifest-derived *shapes* outside markers — product/target markdown tables (`| Product |`
  header row, verified live in `swift-comparison-primitives/README.md:117`), platform-support
  tables, toolchain-floor claims ("Swift 6.0 Concurrency", verified live in
  `swift-rss-standard/README.md:21`). Prose *mentions* of a product name stay legitimate —
  the deny-list targets table/badge shapes, not words. Whether an authored explanation around
  the table is worth keeping is judgment (that is #80's own observation).
- **Owner:** Workspace owns generation + local drift check (doctor/sweep). Central re-check:
  byte-comparing committed block vs. regenerated block **requires manifest evaluation in CI**
  (SwiftPM present in swift-ci jobs, absent in the Python validate-base path) — an explicit
  cost decision the first-pass report skips. Cheapest honest v1: Workspace-side drift check +
  a central shape-deny-list validator (no evaluation needed) in the fleet.
- **FP risk:** none for marker drift; medium for shape deny-list (mitigate: scope to family E,
  exclude code fences that are the generated block itself).
- **Fixtures:** repo-shaped `pass/` (matching block), `fail/` (edited block; hand table
  outside markers), `edge/` (no products → no block required), plus fail-closed: dump-package
  failure yields UNMEASURED, mirroring the lint capability's summary-line adjudication.

### P3. Version-pinned install snippets

- **Current doctrine conflict — must be resolved first.** `readmes.md` *requires* the
  `## Installation` block ("Minimum, always") with pin-form-matches-reality judgment
  (branch pin pre-tag, `from:` once a tag exists); README-008 enforces its presence. The
  agent-first direction (remove or generate) is a **doctrine change**, touching skill prose,
  README-008's family rules, and fixtures in one transaction (the fleet already has a
  writer contract: manifest appended in the same transaction as mechanization,
  [PROMOTE-006]).
- **Decidable?** Yes, once policy is fixed. If generated: same marker machinery as P2 with
  the tag/branch fact from git. If retained hand-written: currency predicate — the `from:`
  version must equal the latest reachable tag (or a branch pin must name the default branch).
  This is README-164, already designed, never implemented.
- **Owner:** central fleet (has `gh`/clone with tags) or Workspace sweep (has local tags);
  central wins because currency drifts with *remote* tags.
- **Detection:** regex `\.package\(url:\s*"…"\s*,\s*from:\s*"([^"]+)"` in README code fences;
  compare against `git ls-remote --tags` / GraphQL `refs`. FP low; live positive exists
  (`swift-rss-standard` pins `from: "0.0.4"`).
- **Fixtures:** unit-tested comparator with an injected tag list (the
  `test-validate-branch-pins.py` pattern — repo-shaped fixtures cannot carry real tags
  cheaply); fail-closed: unreachable remote → unmeasured.

### P4. Volatile inventories in issue bodies

- **Decidable?** Judgeable core (inventory vs. illustration) with decidable shells:
  (a) markdown task-list checkboxes (`- [ ]`) in a Goal-typed body — the ratified grammar
  says "This body contains no checklist"; decidable, near-zero FP;
  (b) live-count assertions — regex for `\b\d+\s+(packages|repositories|issues|rules)\b` is
  **high-FP** (#94's own body legitimately says "the 145 filed exact-owner Issues" as a dated
  pointer to a frozen wave-plan comment). Keep counts report-only or leave to judgment.
- **Owner:** reconciler family (scoped to issues with type Goal, later Task), report-only.
  The authoring-time defense is the Goal form (P5) plus skill sentences.
- **Fixtures:** body-string unit tests; positive (checkbox list in Goal body), negative
  (dated frozen count with comment permalink), fail-closed (issue fetch pagination
  incomplete → unmeasured).

### P5. Record-grammar conformance for Goal/Task bodies

- **Decidable?** Yes for the shell — required-headings-set equality — but **only after the
  grammar is ratified**; today it is de-facto (#79 and #90 agree; #94 deviates), and a
  conformance check against an unratified schema would manufacture violations. Section
  *content* quality stays judgment.
- **Owner (two-layer):** authoring path — a `goal.yml` issue form in
  `swift-institute/.github/.github/ISSUE_TEMPLATE/` (forms render to the exact headings;
  cheap; propagated like bug/change/documentation). Post-edit conformance — reconciler
  section over `type:Goal` issues (GitHub never re-validates edited bodies).
- **Detection:** parse H2 set; require exact set match modulo ratified optional sections.
  FP low once ratified.
- **Fixtures:** conformant/nonconformant body strings; fail-closed: type query failure.

### P6. DocC restatement

- **Decidable?** Shape classes only: install snippets (` ```swift` fences containing
  `.package(`) and platform tables inside `.docc` articles; toolchain-floor claims.
  Prose restatement of manifest facts is judgment.
- **Owner:** extend `validate-docc-structure.py` (or its Swift successor) — DOC-101 is the
  in-fleet precedent for regex content predicates over `.docc`. **Not swift-linter**: the
  walker excludes `*.docc/**` by design, and rules cannot see non-Swift files at all.
- **FP risk:** medium — tutorials legitimately show `.package(` lines; exclude `*.tutorial`
  and `Resources/`. Report-only first.
- **Fixtures:** `fixtures/doc-1xx/{fail,pass,edge}` in the existing suite.

### P7. Broken durable-coordinate format

- **Decidable?** Well-formedness of *present* coordinates is decidable; whether a reference
  should exist is not. Concrete decidable rules:
  (a) cross-repository issue references must be `owner/repo#N` or full URL — a bare `#N`
  aimed at another repo is ambiguous, and intent is not in the artifact, so the honest
  mechanical rule is the *format* requirement, not intent recovery;
  (b) digest references must be algorithm-qualified (`sha256:<64 hex>` or the receipt's
  labeled `digest=` form) — regex, near-zero FP;
  (c) commit SHAs cited in durable records carry repo context (URL or `owner/repo@sha`).
- **Owner:** commit messages currently have **no lint surface at all** (`lint-pr-title.yml`
  covers PR titles only) — a commit-range check in CI is new build; issue bodies → reconciler;
  skills own the authoring rule. Given the pre-release squash-at-release culture
  (LINTING-DESIGN-STATE "History will be squashed at release"), commit-message enforcement is
  the lowest-value predicate in this catalogue; sentence-level skill guidance may be all it
  ever needs.
- **Fixtures:** string-level unit tests; fail-closed: range resolution failure → unmeasured.

---

## 2. What generation Workspace should own

1. **README generated blocks** (products/targets table, platform matrix, install snippet if
   policy keeps one): source of truth is `workspace package dump-package` — SwiftPM's own
   evaluation, satisfying "no second manifest parser" *by name*: the rule should be written
   as "products, targets, and platforms come from `dump-package`; the
   `Workspace.Dependency.Parser` tokenizer is for `.package(` clause surgery only and must
   not grow product knowledge."
2. **Drift check** reusing the established render-and-byte-compare pattern (xcworkspace sync;
   scheme preflight that *refuses to build* on mismatch): `workspace docs check` (or a doctor
   check) re-renders each generated block and byte-compares; `finding` on mismatch,
   `unmeasured` when evaluation fails. Same verdict discipline as lint: a check that could
   not measure never reads clean.
3. **Page enumeration**: inventory-driven, from `Workspace.json` via `Workspace.Layout` —
   never a tree walk (the sweep's own doctrine, including the empty-population refusal).
   Enumerate README/docc/org-profile surfaces per inventory entry + `git ls-files`; emit a
   sorted list with per-file blob SHAs.
4. **Audit receipts**: generalize the two bespoke receipts (lint MANIFEST, installation
   receipt) into one Workspace receipt type implementing #94's spec — canonical
   serialization, sorted records, SHA-256 after independent re-read — so the new Goal's
   cohort-sealing receipt, #79's final receipt, and lint receipts share one implementation.
   This is the single highest-leverage build item: every Goal in this family needs it.

Workspace should **not** own GitHub-record scanning (reconciler's job, per the github skill's
"Institute control-plane integration belongs to `swift-institute/.github`" routing rule) and
should not become the central per-repo CI check (fleet's job).

## 3. What must stay judgment, and the exact sentences

Per the taxonomy: keep guidance decisive; disclose who settles it; name the checked shell.

**`documentation/readmes.md` gains:**
- "Write for the reader the Institute actually has: an agent with the manifest, the symbol
  graph, and `workspace` in reach. A sentence that restates what `dump-package` already
  answers is negative value — it costs context now and drifts later. No tool adjudicates
  reader value; the generated-block drift check only proves the derived table matches the
  manifest, never that the surrounding prose deserves to exist."
- "Keep authored rationale, traps, and judgment; delete or generate everything derivable.
  Whether a hand-written explanation around a derived table earns its keep is your judgment
  to make and record — the validator checks only the derived names and the block bytes."
- Amend the Installation paragraph per the ratified policy outcome, e.g.: "The install block
  is a generated block; never hand-edit inside the markers. The drift check compares bytes;
  it does not judge whether an example belongs here."

**`documentation/docc.md` gains:**
- "A `.docc` article never restates manifest or baseline facts — platforms, toolchain floors,
  install snippets belong to generated surfaces. The structure validator flags the
  recognizable shapes (install fences, platform tables); whether remaining prose is
  restatement is judgment nothing checks."

**`github/SKILL.md` gains (Issues and tracking):**
- "Reference every mutable GitHub entity by its durable coordinate, with the display name at
  most as a parenthetical gloss: the Project as org `swift-institute` ProjectV2 number 2 (its
  title is a rename away from false), issues by `owner/repo#N` or URL, comments by permalink,
  code by `owner/repo@sha`, rule sets by receipt digest. The reconciler flags bare display
  names it can recognize; choosing what to cite is yours."
- "Never edit a record silently into a new meaning: supersede by dated amendment block or
  comment permalink, as #94 does. Nothing checks that an amendment preserves history —
  that is the author's obligation."
- "A body owns no volatile inventory: counts, package lists, and checklists live in
  content-addressed receipts or linked frozen comments. The reconciler flags checkboxes in
  Goal bodies; everything subtler is judgment."

## 4. Gaps and effort classes

| Gap | Build | Effort |
|---|---|---|
| G1 Host ruling for new markdown predicates (Python fleet vs Swift RepositoryPolicy) | a ruling, not code | S |
| G2 Generated-block machinery (markers, generator on dump-package, drift check) | Workspace | M–L |
| G3 Issue-body scanner sections (P1/P4/P5) on the reconciler family | .github | M |
| G4 `goal.yml` issue form encoding the ratified grammar | .github | S |
| G5 README version-currency (README-164) or its generated replacement | fleet | S–M |
| G6 Generic content-addressed receipt type per #94 spec | Workspace | M |
| G7 Commit-range coordinate-format check (low value pre-release) | .github CI | S–M, defer |
| G8 Content fixes found live: org profile still lists Layers 4/5 "planned" against the 2026-07-28 three-layers ruling; `metadata-schema.json` family description cites stale path `Skills/readme/SKILL.md` | #79-cohort / wave-0 content | S |

## 5. Cross-examination of the first-pass report §3

1. **"swift-linter / central policy path: … forbidden restatement patterns, record-grammar
   validation, display-name Project references" — the load-bearing hand-wave.** swift-linter
   can host **none** of these: rules are pure functions over a SwiftSyntax tree
   (`Lint.Source.Parsed` requires `SourceFileSyntax`); the walker includes only `**/*.swift`
   and excludes `*.docc/**`; rules have no API or network access. Every listed class operates
   on markdown or live GitHub objects. The *actual* central policy path — the `.github`
   validator fleet with `validators-manifest.yaml`, `validate-base.yml`, the
   `{fail,pass,edge}` fixture suite, and the reconciler — already exists, already covers
   README/DocC families, and is never named by the report. The slash in "swift-linter /
   central policy path" conflates two systems with different input domains, different fixture
   models, and different receipts.
2. **§4's "linter predicate warns on un-swept repos, denies once a repo's sweep issue
   closes"** — same category error: an AST rule cannot observe sweep-issue state. That gate
   belongs to a central validator/reconciler with API access, keyed by title match per the
   established label-trap doctrine.
3. **"Workspace: generation … no second parser"** — directionally right, under-specified in
   three ways the code makes concrete: the evaluated route is `dump-package` (exists today);
   Workspace already carries a scoped manifest tokenizer that must be fenced off from product
   knowledge; and the central re-check of generated blocks needs manifest evaluation in CI,
   a real cost decision (fleet validators are evaluation-free Python).
4. **"Issue forms: embed the record grammar structurally"** — right and cheap (no Goal form
   exists today), but forms do not survive edits; without the reconciler back-stop this is
   authoring convenience, not enforcement.
5. **"Skills: judgment only"** — consistent with the enforceability taxonomy, but the report
   misses that the skills and rules **already command the opposite** of part of the new
   standard: `readmes.md` mandates the Installation block and pin forms; README-008 enforces
   it; #80 mandates product *coverage*. The conversion edits standing doctrine and rules in
   the same transaction, and every new sentence must obey the honest-voice rules (say which
   shell is checked) plus keep `readmes.md`'s "Where the check and the text disagree" section
   truthful.
6. **What the report gets verifiably right:** the #90 digest pattern is real and implemented
   (`MANIFEST.txt` matches the issue's digest byte-for-byte); the live README drift examples
   check out (`swift-rss-standard` "Swift 6.0 Concurrency", `from: "0.0.4"`;
   `swift-comparison-primitives` hand-maintained product table); #79's body does forbid scope
   injection; and the partitioned-authority durable coordinate (org + ProjectV2 number) is
   exactly how the reconciler already names the Project.
