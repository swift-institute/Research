# Costed migration strategy: converging the Institute's GitHub presence on the agent-first standard

Produced 2026-07-30 by the migration-strategy agent. Read-only with respect to GitHub (all `gh` calls GET);
no file under in the local Institute checkout modified. Inputs: the three whole-population estate audits
(`estate-primitives.md`, `estate-foundations.md`, `estate-standards-records.md`), the enforcement design
(`enforcement.md`), live-GitHub verification (`gh-live.md`), prior-art and literature reviews, the first-pass
report (stress-tested here, especially its §4), plus fresh read-only verification of #79's sub-issue set,
the #94 wave-plan comment (`5129689259`), and the remote org profiles of swift-standards, swift-primitives,
and swift-foundations.

---

## 0. Denominators, calibration, and two fresh live findings

**Population (measured, not the tasking's ~390):**

| Slice | Package roots | READMEs | README lines | .docc catalogues | Notes |
|---|---|---|---|---|---|
| L1 swift-primitives | 202 (201 unique) | 202 | 21,365 | 165 (154 pkgs) | 1 scratch clone inflates denominators |
| L2 swift-standards | 108 (28 top + 80 nested) | 107 | 13,549 | 90 | spans 13+ orgs |
| L3 swift-foundations | 141 | 141 | 21,461 | 64 (62 pkgs) | 5 template generations coexist |
| **Total local** | **451 (450 unique)** | **450** | **~56,400** | **~319** | |
| Remote (#94 measurement) | 471 public non-archived package repos | | | | gap ≈ name-reservation/not-checked-out repos; reconcile at cohort seal |

Record trees: 770 md files / 290,062 lines (Research 630, Issues 87, Internal 29, Workspace 24).
Org profiles: ~17 (institute + 3 layer orgs + 13 authority orgs).

**Defect mass (whole-population, measured):** ~350 provably-false-today statements (drifted product tables 41,
wrong floor claims ~131, broken/stale pins ~57, broken links ~30, dead DocC links 40, wrong counts 19, stale
imports/products ~11, Core residue 9 READMEs, stale org-profile claims); ~3,500+ latent-fragile instances
(316 branch pins, 434 status badges, 272 coenttb-org refs, ~1,202 cross-repo links, 587 signature-coupled DocC
links, 72 name-based badges, 1,198 bare `#N` refs); ~1,400 manifest-restatement blocks; 213 placeholder
catalogues (49 F + 84 S stub catalogues + 80 stub files in P); 166+47 dead Community sections; 137 empty Topics.

**Fresh live finding 1 — #79's sealed set does NOT cover the package estate.** Verified via GraphQL: #79 has 13
sub-issues, 12 closed, 1 open (#80). The children are: Issues#67 (reproducer index), .github#68 (programme-state
model), Workspace#74 (census snapshots), **seven org-profile inventory removals** (swift-standards, swift-ecma,
swift-iec, swift-ieee, swift-incits, swift-w3c, swift-whatwg, swift-riscv `.github`s), .github#117 (fail-closed
scan leg), and #80 (README product-coverage predicate). **No package README is in #79's remediation set.** The
23–61% measured drift in ~450 package READMEs is, per #79's own body ("sealed after page-complete triage; later
unrelated content or policy proposals are new exact-owner work"), *new exact-owner work* — it rides in the new
Goal, not in #79. This reframes §5 below and corrects the first-pass draft's "both cures under #79 first" clause,
which is real only for the ~10 record/org-profile surfaces #79 actually swept.

**Fresh live finding 2 — wave 0 is partly done, partly stale-local.** The swift-standards org profile's 28-row
package table (reported by the estate audit from the *local* checkout) is **already gone on remote** — replaced
by an authorities-routing table (7 rows, durable scope) + native repository-view links: #79's child worked, and
the local checkout lags remote. The swift-primitives profile, by contrast, is **confirmed stale on remote**:
"Core + variants + umbrella" (convention dissolved 2026-06-23), "Each package ships with a DocC catalog" (actual
76%), `from: "0.1.0"` for swift-tagged-primitives (real: 0.10.0). swift-foundations' profile still showcases
`swift-html … from: "0.1.0"` (real: 0.17.2). Two consequences: (a) remaining wave-0 exemplar work =
primitives + foundations + institute profiles, not all 17; (b) **migration receipts must pin remote revisions;
local checkouts are stale in both tags (0 fetched in 449/451 repos) and content.**

**Calibration anchor.** #94's CI-green wave measured 471 repos and filed 145 exact-owner Bug issues in one day;
#79's 8-profile sweep closed in ~a day. One "#94-scale wave" ≈ 60–150 agent-task units. The entire conversion
programme sized below ≈ **1–1.5 such waves** — large but precedented.

---

## 1. Cost model

### 1.1 Unit and cost classes

**1 ATU (agent-task unit)** = one bounded agent session producing one repo-scoped push/PR, one instrument
increment with fixtures, or one batched review session. Tier per the model-effort doctrine: low-tier execution,
mid-tier diagnosis, high-tier planning/judgment/review (same unit, scarcer budget — flagged H below).

Three remediation methods with very different economics:

- **A — central script/generator sweep (bot push).** Precedent: `Sync .gitignore from canon` ×197, issue-form
  materialization ×182 — the fleet already accepts direct bot pushes. Marginal cost/repo ≈ 0.02 ATU
  (verification sampling amortized); cost concentrates in the instrument + fixtures.
- **B — per-repo agent edit** (mechanical-with-context, no deep judgment): 0.3–0.5 ATU/repo, low tier.
- **C — judgment review** (five-disposition adjudication, doctrine, profiles): batched 4–8 repos/ATU at
  mid-high tier; org profiles and doctrine 1–3 ATU each. H.

The decisive modeling fact from the estates: **the defect mass is ~95% method-A reachable.** 96.5% of L3
READMEs carry a mechanically detectable defect; every high-count class is template artifact or restatement of a
machine-readable fact. Per-package hand repair of D1 alone (~1,400 blocks) would cost 150–250 ATU; generation
+ sweep costs ~25–40 including residuals. The cost model is therefore dominated not by defect counts but by
instrument correctness and by how much judgment wave is bought.

### 1.2 Per-defect-class costing (against measured counts)

| # | Class | Measured population | Cure | Method | ATU |
|---|---|---|---|---|---|
| 1 | D1 manifest restatement | ~1,400 blocks; 202 product tables (41 drifted); ~295 toolchain/platform claims (~131 wrong); 431 product-naming snippets; 219/841 products uncovered in P | delete floors/counts; generate product+platform+install blocks from `dump-package` between markers | A: G2 instrument 8–15 + 3 layer sweeps 4–6 + residual B on 25–45 repos (5–10%) 8–19 | **20–40** |
| 2 | D2 pin fragility | 449 pinned snippets (316 `branch:`, 133 `from:`); ~57 broken/stale today; 100% of P's `from:` pins dead | tag-derived snippet in the same generated block; README-164 currency predicate for anything hand-kept; make-safe pre-pass normalizes broken pins to the ratified branch-until-tag rule now | pre-pass A/B 3–6; rest inside G2 | **3–6** |
| 3 | D3 reference fragility | 272 coenttb refs (37+11+5 files); 4+1 renamed-repo refs; 72 name-based badges; ~26 broken relative/LICENSE links; 1,202 cross-repo links | inventory-keyed rewrite sweep (Workspace.json as truth); path-addressed badges; link-existence validator; never-reclaim rule (governance, free) | A: script 2–3 + sweep 1–2 + validator 2–3 | **5–8** |
| 4 | D4 volatile inventories | 434 status badges; 83 numeric claims (19 wrong); ~90 status-prose lines; 3 stale org profiles (remote-verified) | badge/floor/count deletion = template supersession (W0 decision) executed inside sweep #1; profiles authored | A ≈ 0 marginal + C profiles 3–5 | **4–7** |
| 5 | D5 emptiness | 133 stub catalogues + 80 stub files (213 total); 166+47 dead Community blocks; 137 empty Topics; 16 SPI-live placeholders; 77 "YourTarget" fillers | complete-or-delete script (abstract generated from metadata.yaml description); SPI publish gate on placeholder marker; dead sections deleted in sweep #1; mixed-catalogue triage is the only judgment | A 3–5 + B/C triage ~30–50 catalogues 4–8 | **7–13** |
| 6 | D6 DocC link fragility | 40 broken today (4 pkgs); 587 signature-coupled; 17 hash-form; 9 README Core mentions | fix the 4 packages; module-existence validator (DOC-1xx family); lint-ban new hash links; signature links fixed on-touch only (sweep avoided) | B 2 + A validator 3–5 | **5–7** |
| 7 | D7 identity duplication | 65/107 divergent in S (P/F analogues unmeasured) | metadata.yaml `description` = SSOT; lint-equality warn; alignment folded into judgment wave | A 2–3 | **2–3** |
| 8 | Records | 1,198 bare `#N` (157 in active trees: Issues 107 + Internal 30 + Workspace 20); 5 "Institute Work" display refs; 0 durable ProjectV2 coords | qualify active-tree refs; Draft-C-style fixes; reconciler predicates P1/P4/P5 report-only; **exempt Research's 1,049 by ruling** (archival) | A 2–3 + B 1–2 | **3–5** |
| 9 | Issue-body grammar | no `goal.yml`; de-facto grammar (#94 deviates) | goal form; grammar ratification; reconciler back-stop | S/A 2–4 | **2–4** |
| 10 | Doctrine & standard | — | dedicated assessment (per #82 correction), Goal filing, readmes.md/docc.md/github-skill edits, badge/floor/install supersessions, G1 host ruling | C, H | **8–12** |
| 11 | Receipts & enumeration | — | G6 generic receipt type (serves #79 final receipt + cohorts), page enumeration with per-file blob SHAs | instrument | **5–8** |
| 12 | Canary + rollback rehearsal | 10–20 repos | conversion + agent-eval spot-check + one rehearsed revert | B/C | **4–6** |
| 13 | Judgment wave | scoped: ~110 READMEs ≥p75 length + ~25 authored catalogues (NOT all 450) | per-line removal test; #79's five-disposition rule; semantic-review receipts | C batched, H | **22–36** |
| 14 | Coordination | cohort issues, heartbeats, receipts, HOLD-lane liaison with #94 | — | — | **8–12** |

### 1.3 Roll-up and uncertainty

- **Core programme: 88–167 ATU; central ≈ 125–140 ATU** (+15% contingency → envelope **100–190**).
- Tier split: ~25–35 ATU high-tier (rows 10, 13, reviews); remainder low/mid — consistent with the
  low-effort-fleet execution model.
- Top three line items: judgment wave (22–36), D1 conversion incl. G2 (20–40), coordination+receipts (13–20).
- Calendar: dominated by principal-acceptance cycles and CI settling, not agent labor (see §6).

**Sensitivity (ranked):**

1. **Mutation-channel policy.** If per-repo PR + review is required instead of bot push: +100–150 ATU
   (programme nearly doubles). The bot-push precedent exists; settle this in W0. Single biggest lever.
2. **Judgment-wave scope.** Full-fleet adjudication (450 pkgs): +40–60 ATU. Recommended scoping (≥p75 length +
   authored DocC) holds the line; minimum-shape READMEs (43 in S alone are ≤40 lines) pass mechanically.
3. **G2 underestimate.** Multi-org tag lookups, spaced paths (`Sources/JSON Feed Standard/…` broke two audits'
   own tooling), String-constant product DSL (34 false positives in a naive pass): ×1.5–2 on the 8–15.
4. **Residual rate.** 5–10% assumed; L3's heterogeneity (5 template generations, 915-line swift-records) could
   push 15% → +10–15 ATU.
5. **Research-tree exemption** (recommended): saves 10–20 ATU with near-zero value lost (archival memos,
   generated index already exists).

---

## 2. Sequencing

### 2.1 Doctrine/enforcement-first — now proven, not asserted

The estates supply the empirical proof the first-pass draft lacked:

- Every hand-restated fact class converged on 23–61% rot (product tables 24%, coverage 26%, counts 23%,
  P `from:` pins 100% dead, F pins 61% wrong, S floors ~85% wrong) with **zero renames involved**.
- L1 is "100% template-derived, ~100% hand-edited afterwards"; L3 has **≥5 coexisting template generations**
  (Community-section MD5 clusters 23/11/9/2/2). That stratigraphy is the fossil record of previous pages-first
  sweeps without enforcement: each sweep decayed into a new stratum. A sixth unenforced sweep would produce a
  sixth stratum, at ~25%/quarter decay.
- Conversely, the one surface designed as index-of-generated-truth (org-profile repositories-tab links) cannot
  drift, and the #79 child that converted the standards profile held (verified remote today).

So: **no fleet page conversion before (a) the supersessions are ratified and (b) the drift check + shape
deny-list run at least report-only.** The only page work allowed earlier is the make-safe pre-pass (§2.4).

### 2.2 Waves and layer order

W-1 make-safe → W0 doctrine+exemplars → W1 instruments → W2 canary → W3 layer sweeps **L1 → L2 → L3** →
W4 records+DocC → W5 judgment+seal. (Full exit criteria in §6.)

Layer-order rationale (the draft asserts L1→L2→L3 without reasons; the measured reasons happen to support it):

- **L1 first**: the injection pipeline already exists (165 marker files, metadata sync, social-preview
  workflows); templates are most uniform (one family, two sentence generations) — cheapest terrain to validate
  the generator; largest repo count exercises scale early.
- **L2 second**: requires the readmes.md constitution supersession to be settled (its validator *mandates* what
  the standard deletes) and exercises the multi-org coordinate rewrite (13+ orgs, nested authority roots,
  spaced paths) — do it after the generator is proven but while attention is high.
- **L3 last**: most heterogeneous (5 template generations, 8+ license phrasings, 915-line outlier READMEs,
  swift-records' dual-surface tutorial mass) → highest residual rate; schedule when the residual-issue
  machinery is warmed up.

### 2.3 Where the #94 wave-plan pattern applies — and where it must be adapted

Adopt from #94 verbatim: **frozen measurement comment** (batched GraphQL, run-level truth, dated);
**existing-owner preservation** (no duplicate filings — e.g., repos with open #94 CI-red issues); **HOLD list
for volatile heads** (13 repos are in in-flight execution lanes today; conversion sweeps must respect lanes);
**uniform residual-issue titles** discoverable by title search; **content-addressed cohort receipts**;
"independently executable now" framing for pre-doctrine Bug-class fixes.

Adapt, do not copy: **#94 pre-filed 145 per-repo issues because each red repo needed per-repo execution.** A
centrally-scripted, bot-pushed README sweep does not: pre-filing ~450 conversion issues would cost 30–50 ATU of
pure issue lifecycle plus record noise. File instead: one sweep issue per cohort (owns the receipt), plus
per-repo exact-owner issues **only for residuals** (est. 25–45 repos) and per-repo issues where genuine
per-repo work exists (DocC mixed-catalogue triage, judgment wave). This preserves the pattern's auditability at
~10% of its filing cost.

CI-churn discipline (learned from the 2026-07-29 gitignore canon push, which re-ran CI fleet-wide and exposed
155 reds): batch conversion commits with other planned canon syncs where possible; record run-level CI state in
the cohort receipt; don't require per-repo CI green to convert (README-only commits don't build), but never
convert HOLD-lane repos mid-lane.

### 2.4 The make-safe pre-pass (W-1) — new, high-leverage, doctrine-free

~350 statements are provably false **today** and are plain Bug-class defects needing no new doctrine: broken
pins (normalize to the *already-ratified* branch-until-tag rule or the real tag), wrong floor values (correct
to manifest values — not deletion, which awaits the W0 supersession), 6+2 wrong product names, 272 old-org
refs (also a live SwiftPM duplicate-identity hazard, not cosmetics), ~30 broken links, 40 dead DocC links + 9
Core mentions, the scratch clone, the missing LICENSE. Per #94's precedent ("every issue filed here is …
independently executable now" while activation stays paused), this executes immediately, before or in parallel
with the assessment cycle. Cost 6–10 ATU; value: the estate stops actively lying to agents in week 1, and the
floor-correction script is the G2 dump-package plumbing in embryo (the pre-pass doubles as the generator's
first integration test). It also shrinks the half-converted-state risk (§3) at its most dangerous end: wrong
instructions become absent-or-correct instructions.

---

## 3. The half-converted state, in depth

Assume the 40/60 point: ~180 READMEs generated, ~270 legacy.

### 3.1 What concretely breaks

1. **Exemplar-copying loops.** Fleet agents infer conventions from neighboring repos. At 40/60 a sampled
   exemplar is legacy with p≈0.6 → new/edited pages minted in the legacy form *during* conversion; the debt
   grows while being paid. This is the dominant failure, and the fix is instruments-first sequencing: flip the
   canonical template + validator warn **before** the first cohort converts, so the path of least resistance is
   the new form even where pages are old.
2. **Marker-discipline confusion.** Agents hand-edit inside markers on converted repos (drift check catches it
   — but only warn-tier until the cohort seals) or add markers ad hoc to legacy repos (creating blocks no
   generator owns). Guard: the drift check treats marker-present-but-unregistered blocks as findings, and the
   metadata flag (below) tells agents which regime a repo is in.
3. **Contradictory fleet self-description.** Half the fleet asserts "active development" badges, floors, and
   counts; half asserts nothing. Literature: internally conflicting records are a measured failure mode
   (context clash; stale-but-coherent text is *believed*). The make-safe pre-pass removes the *false* half of
   this hazard before conversion begins; what remains (true-but-inconsistent) is tolerable.
4. **Bimodal audits.** Fleet-wide greps and coverage metrics (e.g. #80's) return mixed shapes; any auditor
   unaware of the partition undercounts or double-counts (the estate audits' own traps: spaces, tagless
   checkouts, stale local content). Guard: audits enumerate from Workspace.json + the conversion flag, never a
   tree walk (existing sweep doctrine).
5. **Validator wall.** Flipping shape deny-lists fleet-wide at 40/60 would redline ~270 repos at once — the
   mass-red anti-pattern #94 just spent a wave cleaning. Hence the ratchet below.
6. **Mixed snippet styles for external consumers.** Converted repos advertise tag pins; legacy advertise
   `branch:`. Internal manifests compose via `branch: "main"` anyway (measured), so the risk is confined to
   external copy-paste graphs; short conversion windows per org-cohort minimize it.

### 3.2 Guards that make the intermediate state safe

- **A machine-readable conversion flag in `.github/metadata.yaml`** (e.g. `readme.schema: 2` beside the
  existing `readme.family`) — set by the conversion sweep itself, schema-enforced, bot-synced. This is the
  load-bearing guard the first-pass draft lacks: it makes every repo *self-describing* about which regime it is
  in, readable by validators, auditors, and agents alike without any per-README banner churn (two avoided
  fleet sweeps).
- **Warn→deny ratchet keyed on in-repo machine state + cohort receipts — not on sweep-issue state.** The
  draft's "denies once a repo's sweep issue closes" fails twice: swift-linter cannot host it (AST-only, no
  markdown, no API — enforcement report), and issue-state keying repeats the label-trap the reconciler doctrine
  already retired (a prior sweep keyed on a label that never existed and silently never fired). Correct form:
  central validators warn where `readme.schema < 2`, deny violations where `readme.schema: 2`; the flag flips
  only via the sweep; the cohort receipt is the audit authority for who flipped when.
- **Cohort sealing**: convert in sealed cohorts (canary 10–20; L1 in two ~100-repo cohorts; L2 108; L3 141),
  each with a frozen membership list and a content-addressed receipt (pre/post blob SHAs per file, generator
  version, rule-set digest). Between cohorts: CI settle + drift-check green before the next launches. Caps the
  blast radius of a wrong generator at one cohort (§4).
- **Make-safe pre-pass** (§2.4): the mixed state is dangerous in proportion to how much of the legacy half is
  *false*; the pre-pass takes that to ~zero before mixing begins.
- **Existing #94-style HOLD discipline** for in-flight lanes.

### 3.3 What an agent reading the half-converted estate must know (and where it lives)

Four facts, each with exactly one home:

1. **Which regime this repo is in** → `metadata.yaml` `readme.schema` (+ the presence of generated-block
   markers). Never inferred from page style.
2. **What to trust regardless of regime** → skills sentence (wave 0): products/targets/platforms from
   `workspace package dump-package`; tags from the remote (`git ls-remote`), never local; README pins are
   advisory until the repo's flag is 2. One line each in the documentation and workspace skills.
3. **What never to do** → hand-edit inside markers; copy a legacy README's snippet style into any new page;
   treat the org-profile prose as inventory (routing only).
4. **Where conversion state is authoritative** → the cohort receipts linked from the Goal's sweep issues —
  not README appearance, not issue counts.

The org profiles carry one dated line during conversion ("READMEs are converging on generated blocks; a repo's
`readme.schema` declares its state; receipts: <link>") and lose it at seal. Skills carry the durable rules.
Per-README banners are rejected: 2×450 file-touches for information the flag already carries.

---

## 4. Rollback and blast radius

Scenario: the generated-README design is discovered wrong after ~200 conversions.

**Failure taxonomy, because "wrong" differs:**

- **(a) Generator emits wrong facts** (worst): wrongness is *uniform and enumerable* — unlike hand rot, one
  patch + one re-render fixes all 200 identically (2–3 ATU + CI churn). This asymmetry is itself an argument
  for generation: hand-wrong is 41 different wrongs, generated-wrong is one wrong 200 times, fixable at one
  point. Canary (W2) + #90-model fixtures + drift check make reaching 200 with a fact bug unlikely.
- **(b) Form is wrong** (agents perform worse with the new layout): detected at canary by the instrumented
  agent-eval spot-check (literature §7.5: treat the standard's predicates as instrumentable hypotheses — run
  task evals against converted vs legacy cohorts *before* fleet sweep). Fix-forward: generator v2, re-render.
- **(c) Doctrine reversal** (e.g. badges turn out to be wanted): a supersession decision; regenerate with the
  reinstated block. Receipts are marked superseded, never deleted.

**Mechanics that make rollback cheap — all must be in the sweep design from day one:**

1. **Two-commit discipline**: per repo, commit 1 = deletions/corrections of volatile lines; commit 2 = marker
   block injection. Uniform commit subjects (fleet-sync precedent). Selective `git revert` of either action is
   then scriptable fleet-wide.
2. **Markers delimit the blast radius**: everything generated sits between `<!-- workspace:generated:<kind>
   v<N> sha256:… -->` markers carrying generator version + digest. Mixed-generator states are enumerable;
   authored prose is never inside markers; rollback never touches authored text.
3. **Receipts are the rollback map**: each cohort receipt records per-file pre-conversion blob SHAs — restore
   is a mechanical checkout of enumerated blobs, not archaeology. (This makes G6, the generic receipt type, a
   rollback instrument, not just an audit one — build it before the first cohort, not after.)
4. **Judgment wave strictly last**: mechanical rollback stays clean only while no judgment edits interleave
   with generated-block commits. If adjudicated deletions were mixed in, per-repo history surgery would be
   needed — the one genuinely expensive rollback. Hence W5's position and its own semantic-review receipts.
5. **Rehearsal**: W2 exit criteria include one performed revert on a canary repo. An untested rollback path is
   a hypothesis, not a guard.

**Cost of the worst credible case** (design abandoned at 200 conversions): full revert sweep 2–4 ATU + ~1 day
CI churn + supersession records. No authored content is lost at any point; the irreversible set is empty while
the two-commit + judgment-last rules hold.

---

## 5. Interaction with Goal #79

**The measured relationship is narrower and cleaner than the draft assumed.**

1. **#79 will never touch the package estate** (live finding, §0): its sealed set is org profiles + records +
   the #80 predicate; 12/13 children closed. The estate's 23–61% README drift is new-Goal work by #79's own
   sealed-set sentence. Consequence: the draft-Goal clause "a page needing both cures is remediated under #79
   first" is real only for the handful of #79-cohort surfaces (already done, remote-verified for standards) and
   must not be read as a fleet ordering constraint — otherwise the new Goal would wait on work #79 will never do.
2. **Generation subsumes drift repair.** For restatement classes, converting *is* the fact-fix: the generated
   block replaces the drifted table/pin/floor. A separate pre-generation "#79-style" fact-repair pass over 450
   READMEs would be 40–80 ATU of double work discarded by the sweep that follows. The only pre-generation
   repair that pays is the make-safe pre-pass (broken-today items, W-1), because it is cheap, immediate, and
   doubles as the generator's integration test.
3. **#80 is the single live coupling point — and the deadlock risk.** #80 (open, Normal, #79's last child)
   owns the product-coverage predicate. Design it on the same `dump-package` evaluation G2 uses (its own text
   requires reusing the Workspace manifest model; no second parser), run it report-only until cohorts convert,
   and let generated product blocks satisfy it by construction. Two failure orderings to forbid explicitly in
   the new Goal's assessment: (a) if #80 enforced *before* generation exists, agents hand-patch 58+ packages
   (219 uncovered products in P alone) that the sweep then overwrites — wasted work; (b) if #80's completion
   were read as *fleet-green coverage* while the new Goal's cohort seal waits on #79's final receipt, the two
   Goals deadlock (#79 waits on coverage ← generator ← new Goal ← seal gate ← #79 receipt). Resolution, per
   #80's own text ("owns the product-coverage predicate only"): #80 completes when the predicate exists,
   fail-closed, fixture-backed — its findings are exact-owner work like every other predicate's. Then #79 can
   close on instrument-done, the receipt exists, and the new Goal's seal gate is satisfiable.
4. **Receipt gating stays as drafted, and stays cheap**: #79's final receipt gates *cohort sealing only* —
   doctrine, instruments, canary, and even early cohorts can run before it. Given (3), #79's closure is likely
   to precede the first layer sweep anyway, making "conversion audit runs against post-#79 revisions" trivially
   true rather than an ordering constraint.
5. **Shared machinery**: G6 (generic content-addressed receipt type) should implement #79's final receipt, the
   new Goal's cohort receipts, and future #94 receipts from one implementation — build it in W1; it is the
   single highest-leverage shared component (and per §4, also the rollback map).

---

## 6. Timeline in waves, with exit criteria

Calendar assumes the demonstrated cadence (471-repo measurement + 145 filings in a day; 8-profile sweep in a
day); the long poles are principal-acceptance cycles and CI settling. **Nominal ~6 weeks; aggressive 3;
conservative 10.** ATU totals from §1.3.

| Wave | Content | ATU | Calendar (nominal) | Exit criteria |
|---|---|---|---|---|
| **W-1 Make-safe + hygiene** (starts immediately; no doctrine needed) | correct ~350 false-today statements in place (pins→ratified rule, floors→manifest values, product names, old-org refs incl. SwiftPM-identity hazard, broken links, dead DocC links); evict scratch clone; add missing LICENSE; frozen measurement comment | 6–10 | days 1–4 | zero statements provably false against manifest/remote at the receipt revision; measurement comment frozen; no HOLD-lane repo touched |
| **W0 Doctrine + exemplars** | dedicated assessment → Goal filed/accepted (per #82 correction); supersession decisions (badges, floors, install form — these amend the ratified readmes.md constitution, not mere cleanup); G1 host ruling (Python fleet vs Swift RepositoryPolicy); mutation-channel policy (bot push vs PR) settled; `goal.yml`; skill sentences (incl. §3.3 trust rules); primitives/foundations/institute org profiles; #94 Draft-C micro-fix | 10–15 | days 2–8 | assessment accepted; standard text merged at semantic owners; goal form live; 3 remaining org profiles conform (receipted); channel policy recorded |
| **W1 Instruments** | G2 generated blocks + byte-compare drift check (dump-package only); G6 receipt type + page enumeration (blob SHAs); coordinate-sweep script; validator additions (shape deny-list, module-existence, placeholder/SPI gate, badge form, old-org ban) — all report-only; reconciler P1/P4/P5 report-only; `readme.schema` field in metadata schema; #80 predicate lands report-only on the same evaluation | 18–28 | days 5–16 | every predicate runs fleet-wide report-only with #90-model positive/negative/fail-closed fixtures green; drift check in doctor; G6 used by ≥1 real receipt |
| **W2 Canary cohort** | 10–20 repos across all layers incl. hard cases (spaced names, nested standards, fork-heritage render-primitives 3.2.2, swift-records); agent-eval spot-check converted vs legacy; one rehearsed rollback | 4–6 | days 14–19 | zero drift findings after settle; no agent-task regression observed; revert rehearsed and receipted; design sign-off |
| **W3 Layer sweeps L1→L2→L3** | per cohort: sweep issue → two-commit bot push → CI settle → cohort receipt → validator deny for that cohort (keyed on `readme.schema`) → residual per-repo issues (est. 25–45 total) | 20–35 | days 17–32 | per layer: 100% cohort repos converted+flag-flipped+receipted or carried as named residual issues; deny active; no unknown surface; #80 green on converted cohorts |
| **W4 Records + DocC** | qualify 157 active-tree bare refs; Research-exemption ruling; complete-or-delete sweep over 213 placeholder catalogues (+80 P stub files); fix already-covered by W-1 stays; reconciler deny for new records | 12–20 | days 26–38 | zero placeholder text on any shipped surface; SPI gate live; reconciler green on active records; ruling recorded for Research |
| **W5 Judgment + seal** | five-disposition adjudication over ~110 long READMEs + ~25 authored catalogues with semantic-review receipts; identity-sentence alignment; final page-complete audit at resulting revisions; cohort seal (gated on #79 final receipt); closing report | 22–36 | days 32–45 | every cohort page has a terminal disposition; final content-addressed receipt (inventory revision, page revisions, rule digest, controls); Goal closes `completed` |

Cross-wave rules: judgment never interleaves with mechanical commits (§4); conversion never touches HOLD-lane
repos; each wave's receipt is a G6 receipt; coordination budget (8–12 ATU) spans all waves.

---

## 7. Stress-test of the first-pass report's §4 against the measured estate

Verdicts, item by item:

1. **"Doctrine and instruments first, pages last" — CONFIRMED, and now quantified.** 23–61% decay on every
   hand-restated class with zero renames; L3's five coexisting template generations are the fossil record of
   pages-first sweeps without enforcement. The claim graduates from principle to measurement.
2. **"Mechanical wave … with pre-filed exact-owner issues (the #94 wave-plan pattern)" — OVER-ENGINEERED as
   stated.** #94 pre-filed 145 issues because each repo needed per-repo execution; a central bot-push sweep
   does not. Pre-filing ~450 conversion issues ≈ 30–50 wasted ATU + record noise. Keep the pattern's
   measurement-freeze, HOLD lanes, existing-owner preservation, receipts; file per-cohort sweep issues and
   per-repo issues only for residuals and genuinely per-repo work (§2.3).
3. **"Judgment wave … small per package after the mechanical wave" — DIRECTIONALLY CONFIRMED, UNSCOPED.**
   Bodies are indeed bespoke-and-short (template mass dominates all three estates), but small × 450 is still
   the programme's largest line item. It needs the explicit scoping rule (≥p75-length READMEs + authored
   catalogues; minimum-shape pages pass mechanically), reuse of #79's ratified five-disposition semantic-review
   rule, and the literature's per-line removal test as the adjudication question.
4. **"Sequencing L1 → L2 → L3; org profiles and .github records in wave 0 as exemplars" — CONFIRMED with
   corrections.** The order is right for reasons the draft doesn't give (L1's existing injection pipeline; L2's
   constitution supersession + multi-org coordinates; L3's heterogeneity/residuals). The exemplar claim is
   stale: 8 org profiles were already converted under #79 (standards verified live); wave 0's real remainder is
   primitives + foundations + institute profiles (all three verified stale on remote today).
5. **"Linter predicate warns on un-swept repos, denies once a repo's sweep issue closes" — WRONG HOST, WRONG
   KEY.** swift-linter is AST-only (no markdown, no API — it can host none of this); the actual hosts are the
   `.github` validator fleet + reconciler. Keying deny on issue state repeats the retired label-trap; key on
   in-repo machine state (`readme.schema` + markers) with cohort receipts as audit authority (§3.2).
6. **Missing from §4 entirely (each material at this estate's scale):** rollback design (two-commit, versioned
   markers, receipts-as-rollback-map, rehearsal — §4); the #80 coupling and its deadlock (§5.3); the make-safe
   pre-pass (§2.4 — ~350 false statements are executable-now Bug work per #94's own precedent); canary with
   instrumented agent-eval; DocC complete-or-delete at scale (213 placeholder catalogues vs the draft's worry
   about hash links, which measure 17 instances fleet-wide); the multi-org coordinate surface (13+ orgs as the
   highest-blast-radius renameable names); the Research-tree exemption decision; estate hygiene as
   receipt-integrity work (scratch clone, tagless checkouts, stale local content — §0's live finding 2).
7. **Where the draft is right and cheap, keep it verbatim:** doctrine-before-pages; sealed cohorts +
   content-addressed receipts; consume-not-absorb relationship to #79; commit-message enforcement kept to
   skill guidance (squash-at-release culture makes CI enforcement the lowest-value predicate — deferring G7 is
   correct).

---

## 8. Verification traps for the executing programme (from the audits' own failures)

1. Local checkouts lie twice: no tags fetched (449/451 repos) and content lags remote (standards profile).
   Every receipt pins remote revisions; every tag claim uses `ls-remote`/API with semver sort.
2. Institute paths contain spaces; all fleet tooling NUL-delimits (`-print0`) or uses `while IFS= read -r`.
3. Product names come only from evaluated manifests (`dump-package`); naive greps produced 34 false positives.
4. `Workspace.json` is the only enumeration authority; tree walks and `find` counts drift (scratch clones,
   build sandboxes with 170 phantom ci.yml copies).
5. Run-level CI conclusions, not check-rollups (#94's measured over-reporting).
6. A check that could not measure reports `unmeasured`, never clean — for every new predicate, per the
   established doctor/lint verdict discipline.
