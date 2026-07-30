# Agent-first GitHub presence: final synthesis report

Produced 2026-07-30 by the synthesis agent. Inputs: the first-pass report (stress-tested, not
ground truth) and nine research files (literature, prior-art, gh-live, enforcement, three
whole-population estate audits, migration, adversarial critique). Two load-bearing critique
claims re-verified live by this synthesis (read-only `gh` GET, 2026-07-30): #79 carries
exactly two comments and no sealing receipt; #80's body verbatim rejects generated READMEs
("Generate complete READMEs from manifests. Rejected because the useful descriptions,
examples, and grouping are authored documentation"). Nothing was filed or mutated anywhere;
no file in the local Institute checkout was touched.

Where agents conflicted, this report decides and says why. Twelve adjudications are marked
**[ADJ-n]** at the point of decision and indexed in §6.

---

## (a) Executive decision summary

**Disposition: file ONE new Goal in `swift-institute/.github` — substantially repaired from
the first-pass draft — and do not evolve #79.** The Goal charters two things honestly named:
(1) ratification of the agent-first authoring standard (durable-coordinate references, a
versioned minimal record grammar, a page-content contract), which no current authority owns
(gh-live overlap scan: zero existing issues); and (2) a finite, sealed, receipted conversion
episode over the fleet's authored surfaces — which is **the same disease #79 cured for its
sealed activation cohort, now at fleet scale**, not a "sibling disease". #79's 13 children
never touched the package estate (GraphQL-verified); its own body routes broad recurrence to
new assessed work; the #90→#94 consume-not-absorb precedent gives the exact shape.

**The page-content contract is deletion-first, not generation-first.** The critique's
strongest attack (the #80/generation/agents-only trilemma) is conceded and resolved: derived
facts (status badges, toolchain/platform floors, numeric counts, bare product/target tables)
are deleted, not regenerated — the manifest and `workspace package dump-package` are the
projection. Product coverage is satisfied the way ratified #80 designed it: authored naming
plus a fail-closed predicate. This kills the consensus's most expensive instrument (fleet
README generation, 8–15 ATU ×1.5–2 plus a perpetual regeneration tax), removes the need to
supersede #80, and is safe under any readership ruling.

**What is filed:** the dedicated assessment (required before admission per the #82
correction), then the Goal (Draft A in the companion drafts file), an optional additive
boundary comment on #79 (Draft B), and — only after ratification, principal-authored — the
#94 micro-fix amendment (Draft C). The Goal contains an explicit receipted canary gate with
a named abort path (close `not planned` + separately assessed successor), which buys the
two-stage alternative's honesty about unmeasured benefit without a second
principal-acceptance cycle — the demonstrated long pole.

**What starts immediately, disposition-independent:** the make-safe pre-pass — ~350
provably-false-today statements (dead pins, wrong floors, wrong product names, old-org
install URLs, broken links, dead DocC links) are Bug-class exact-owner work under existing
doctrine, 6–10 ATU, per #94's own "independently executable now" precedent.

**Cost:** revised programme envelope **≈ 85–160 agent-task units** (central ~110–120;
deletion-first saves 15–25 ATU against the consensus's 100–190), roughly one #94-scale wave;
nominal 6 weeks, dominated by principal-acceptance latency and CI settling, not agent labor.
Two W0 decisions swing cost more than everything else combined: the mutation channel (bot
push vs per-repo PR, ±100–150 ATU) and the enforcement-host ruling (Python validator fleet
vs Swift RepositoryPolicy).

**The measured justification** (whole-population, three layers, 451 local package roots):
every hand-restated fact class has already rotted at 23–61% with zero renames involved —
41/172 product tables wrong (24%), 219/841 products unnamed (26%), 27/44 L3 pins wrong
(61%), 16/16 L1 `from:` pins dead (100%), ~131 toolchain/platform claims false, 213
placeholder DocC catalogues, 1,198 bare `#N` references, and 0 durable ProjectV2 coordinates
anywhere in the local record trees. Derivation without regeneration is the active defect
engine; deletion plus enforcement is the cure that cannot re-rot.

---

## (b) The ratified framework

### b.1 Verdicts on the first-pass's five principles

| # | First-pass principle | Verdict | What changed and why |
|---|---|---|---|
| P1 | Under-specify prose, over-specify structure | **REVISED — split by genre** | The literature splits it: prune restatement on *standing-rule* surfaces (80%-removal result; per-line test), but *task records* demonstrably fail under-specified — SWE-bench Verified flagged **38.3%** of tasks for underspecified statements; short subagent briefs caused duplicated work. Restated: **prune restatement everywhere; over-specify contracts (objective, scope boundary, acceptance criteria, verification) in task records; over-specify structure in both** (literature §2.5, §6). |
| P2 | Progressive disclosure with canonical entry points | **SURVIVED** | Three-level skill loading, deferred tools, LC-vs-RAG routing, attention economics all converge. Two riders: disclosure boundaries must match decision boundaries (Cognition), and entry-point indexes work only when *directed* — llms.txt as crawler bait is folklore (literature §2.4, §6). |
| P3 | SSOT per fact; generated views only with drift checks | **SURVIVED — now with a mechanism** | Knowledge-conflict evidence explains *why* stale copies beat absence at being harmful: coherent-but-stale text is believed; partial matches trigger confirmation bias (Xie et al.). The estates supply the decay curve: 23–61% rot per restated class (literature §2.1; estates §3). |
| P4 | Persistent, machine-checkable identifiers | **REVISED — from principle to policy** | Direction unanimous (prior-art L1–L4), but as stated it was a principle without a coordinate policy. Now: the **pair rule** (durable coordinate + semantic gloss — opaque IDs alone measurably hurt retrieval precision), **define-once-per-record** (the critique's token-bill objection, conceded), a **trusted-coordinate ranking**, the **never-reclaim rule**, **resolution auditing**, and **org names ranked as the highest-blast-radius renameable coordinate** (the estate spans 13+ orgs; `swift-rfc-2387` already moved orgs leaving stale install coordinates). |
| P5 | Expressive interfaces over documentation | **SURVIVED — one guardrail** | SWE-agent ACI evidence; "prefer code over descriptions". Guardrail: trigger-condition prose ("when to reach for this") is part of the interface, not documentation-to-delete — description refinement alone gave a 40% completion-time delta. #80's ratified "authored explanations are reader value" holds (literature §2.9, §6; critique §2.3). |

Two principles are **added**:

- **P6 — Enforcement placement law** (from enforcement + prior-art L7): advisory prose never
  carries a rule a machine can check; every predicate lands at an owner whose *input domain
  actually contains the surface*, with positive/negative/fail-closed fixtures (#90 model);
  write-time shaping (forms, templates) plus read-time validation (validators, reconciler),
  because platform-side write-time checks fail silently (CODEOWNERS precedent) and GitHub
  never re-validates edited bodies.
- **P7 — Staged convergence** (from migration): make-safe before doctrine, doctrine before
  pages, sealed cohorts with content-addressed receipts, an instrumented canary before any
  fleet sweep, rollback designed in (two-commit discipline, receipts as rollback map,
  rehearsed revert). L3's five coexisting template generations are the fossil record of
  pages-first sweeps without enforcement.

### b.2 The standard, per surface

**Issue and Goal records** (grounded: SWE-bench Verified; Anthropic multi-agent delegation;
Lost in the Middle; knowledge-conflict; CloudEvents/Confluent/protobuf/PEP via prior-art):

1. **Self-containment is the top upgrade** — objective, exact-owner scope, out-of-scope
   statement, an acceptance/verification predicate an agent can run or check, pointers (not
   copies) to sources. The first-pass under-weighted this relative to identifier hygiene.
2. **The pair rule**: every reference to a mutable entity carries a durable coordinate
   (canonical URL, `owner/repo#N`, org+ProjectV2 number, `owner/repo@sha`, digest+locator)
   *paired* with a semantic gloss. **Define once per record** (a coordinates block or
   first-mention parenthetical), short form thereafter — the pair everywhere would inflate
   exactly the surfaces the length evidence says degrade. **[ADJ-5]** Order is style, not
   substance: name-or-role first serves lexical anchoring (NoLiMa: attention needs literal
   matches; agents grep "Institute Work", not node IDs), the parenthetical coordinate serves
   durability; the predicate checks *pairing within scope*, never order. When the leading
   token is a mutable display name, mark it ("currently titled …").
3. **Position discipline**: binding contract sections first, navigation last, nothing
   normative mid-body (U-shaped attention). The fixed section grammar delivers this free.
4. **Supersession**: dated amendment blocks in place (or in-place edit with a dated audit
   note pointing at the ruling comment), never silent edits, never comment-only correction —
   stale body text left standing is *believed* (knowledge-conflict evidence) and a
   body-vs-comment contradiction is a context clash. PEP/ADR end of the spectrum, not the
   Rust-RFC end. #94's amendment block is the house pattern.
5. **No volatile inventories** in bodies: counts, package lists, checklists live in frozen
   dated comments or content-addressed receipts; every digest carries an adjacent resolvable
   locator (reversible compression). The receipt shape is in-toto's Statement: subject =
   exact revisions by digest, predicateType = versioned rule-set identity, predicate =
   result. #90/#94 already match it in substance.
6. **Minimal record grammar** **[ADJ-12]**: required core = kind, owner coordinate, status,
   grammar version (CloudEvents shape); everything else optional/extension. Self-describing
   version; declared BACKWARD compatibility ("every vN-conformant record remains valid under
   vN+1, or the change ships with a filed migration sweep"); retired kinds/fields reserved,
   never recycled; **prospective-only with an explicit grandfather clause** — the ratified
   grammar must not manufacture retroactive violations in the principal-accepted #94 (the
   critique's n=3 ossification attack, conceded). The full #79/#90 section list becomes the
   *recommended Goal template* rendered by the issue form, not the required core.

**Package READMEs** (grounded: Claude Code include/exclude table; #80's ratified philosophy;
the estates' measured value boundary — "the highest-value README content observed is exactly
what is NOT derivable from the manifest"):

1. **Keep**: one-paragraph identity; when-to-reach-for-this judgment; authored product
   naming with one-line per-product guidance (this satisfies #80 as designed); the uniform
   quick-start line (`workspace package build|test` routing for Institute agents); canonical
   links (manifest, DocC, owning records). Apply the per-line test in the judgment wave:
   "Would removing this cause an agent to make mistakes?"
2. **Delete, do not generate** **[ADJ-1]**: status badges (434 copies of one unfalsifiable
   claim), toolchain/platform floor prose (~131 provably false today), numeric inventory
   claims (23% wrong), bare product/target/platform tables (24% drifted), dead Community
   sections (213 blocks, zero real links). Deletion is a **recorded supersession of the
   readmes.md constitution's badge and floor mandates** — never silent cleanup.
3. **Install snippet**: keep one; normalize now to the already-ratified branch-until-tag
   rule (make-safe); currency enforced by the designed-but-unimplemented README-164
   predicate against remote tags; the release workflow bumps the pin in the release commit
   (small, well-owned generation — not fleet G2). Canary decides whether fuller generation
   ever pays.
4. **References**: repo-relative links; no branch deep links; pair rule for cross-repo
   references; never `github.com/coenttb/*` from Institute docs (272 live instances).
5. README ≠ agent instruction file: operational detail stays in skills/AGENTS-class
   surfaces; README is identity + routing + judgment (three-vendor convergence).

**DocC** **[ADJ-8]** (grounded: estates — the first-pass's emphasis was inverted):

1. The primary agent surface is **inline `///` at the declaration site and the symbol
   graph** — currently a dark surface: no audit measured doc-comment coverage. Instrument it
   (W1) before optimizing anything else.
2. **Complete-or-delete the 213 placeholder catalogues** (84/90 in L2, 49/64 in L3, 80
   stub files in L1) — "Replace this line…" is anti-content that costs a fetch and lies to
   coverage metrics; gate `.spi.yml` publishing on the placeholder marker (16 live on SPI
   today). This, not link fragility, is the DocC programme: hash-form links measure 17
   instances fleet-wide.
3. No manifest restatement in `.docc`; prefer auto-curation (curate only where ordering is
   judgment); module-existence validation for symbol links (31 broken today from the
   core-dissolution sweep); signature-coupled links (587) fixed on touch, not swept.

**Org profiles** (grounded: directed-index reading of llms.txt; #79's own child conversions):

1. Durable scope + curated routing to canonical entry points; **no hand-maintained package
   inventories** — the converted swift-standards profile (verified live on remote) is the
   exemplar; the swift-primitives profile (still teaching the dissolved Core convention and
   a dead pin) and swift-foundations profile (showcasing `from: "0.1.0"` against a real
   0.17.2) are the wave-0 remainder, with the swift-institute profile.
2. No undated status prose ("pending", "public alpha", license reconciliation) — date it or
   route it to the owning record.

**Commit messages** **[ADJ-6]**: skill-sentence guidance only — reference the owning issue
by durable coordinate; state the invariant changed; no AI attribution (standing user rule).
The literature's trailer protocol (Lore et al.) is marked **non-transferable at present**:
fleet history is bot-sync noise (4/606 subjects reference an issue) and the programme
squashes history at release, which destroys the append-only-log premise the
durability-bonus argument rests on. Defer G7 (commit-range CI checks); revisit if squash
culture changes.

**The readership premise** **[ADJ-7]**: the standard is **decoupled from the strong
"agents are the ONLY readers" assumption**. That assumption is unratified (it lives in boot
context and a memory note, against the workspace rule that durable rulings belong in
canonical stores), and the estate leaks around it (SPI opt-ins, social-preview generation,
"public alpha"). The standard as ratified needs only the weaker, defensible form: *agents
are the primary readers; no surface may depend on human memory or human-only rendering;
human legibility is preserved because it measurably serves agents too* (semantic-identifier
evidence). Every deletion above is justified by measured rot or dead weight, not by reader
denial. Whether external/human adoption is a near-term objective is asked, not assumed (§g).

---

## (c) The measured estate

Whole-population surveys, no sampling. **Population: 451 local package roots (450 unique —
one scratch clone), not the tasking's ~390**: L1 swift-primitives 202 (201 unique), L2
swift-standards **108** (28 top-level + 80 nested under 12 authority roots, spanning 13+
GitHub orgs), L3 swift-foundations 141. 450 READMEs (~56,400 lines), ~319 DocC catalogues.
Remote: 471 public non-archived package repos (#94's frozen measurement); the 471-vs-451 gap
(name reservations, not-checked-out repos) is reconciled at cohort seal. Record trees: 770
markdown files / 290,062 lines (Research 630, Issues 87, Internal 29, Workspace 24). Org
profiles ≈ 17.

### c.1 Defect classes, measured

| Class | Fleet numbers (by layer where they differ) | Already false today? |
|---|---|---|
| **D1 restatement** | ~1,400 manifest-restatement blocks. L1: 172 product tables (**41 drifted, 24%**; 149 products missing, 20 ghost rows), **219/841 products named nowhere (26%)**, 178 toolchain claims (wrongness unmeasured). L2: 101/107 product-name restatement (6 wrong), ~50 Swift-floor + ~35 platform claims **all contradicting uniform 6.3.3/.v26**. L3: 28/59 Swift claims wrong (**47%**), 18/77 macOS wrong (23%), 2/132 product refs broken | **~131 wrong floor claims + 41 drifted tables + 19 wrong counts** |
| **D2 pins** | 449 pinned snippets: 316 `branch:"main"`, 133 `from:`. L1: **16/16 `from:` pins dead (100%)**, ≥7 repos tag-published while README says branch → **≥23 contradicting remote**. L3: **27/44 wrong (61%)**. L2: 7/51 broken/stale (13.7%) | **~57 broken/stale now**; every future tag mints more |
| **D3 references** | ~1,200 cross-repo links; **272 `github.com/coenttb/*`** (24 packages' own install URL wrong-org — a live SwiftPM duplicate-identity hazard); 5+1 renamed-repo refs surviving on redirects; 72 name-addressed CI badges; ~30 broken links (25 `[LICENSE](LICENSE)` L3, 1 L1, 2 dead docs links, renderer-dependent idioms) | ~30 broken; rest latent until rename/reclaim |
| **D4 volatile prose** | **434 status badges** (one claim × 434 copies); 83 numeric count claims in L1 (**19 wrong, 23%**); ~90 status-prose lines (incl. "planned: swift-rfc-9111/9112" — **both exist**); 2 of 3 layer org profiles stale **on remote** | drifting now |
| **D5 emptiness** | **213 placeholder DocC catalogues/files** (L2 84/90 = 93%; L3 49/64; L1 80 files across 71 pkgs); **16 placeholders live on Swift Package Index**; 166+47 dead Community sections (0 real links); 137 empty `## Topics`; 77 `YourTarget` fillers | static rot; every fetch returns nothing |
| **D6 DocC links** | **40 broken today** (31 dissolved-module links + 9 cross-module, residue of the 2026-06-23 Core dissolution; +9 READMEs naming dissolved products); 587 signature-coupled links; 17 hash-form | 40 broken now |
| **D7 identity duplication** | The "what is this package" sentence lives in ≥4 places; L2 measured: **65/107 (61%) README-vs-metadata divergent**. `metadata.yaml.description` (110/110 present) is the natural SSOT | drifting now |
| **Records** | **1,198 bare `#N` vs 227 repo-qualified (84% ambiguous outside home repo)**; **5 bare "Institute Work" display references; 0 durable ProjectV2 coordinates anywhere**; 46% of files use now-language; machine paths contained to private Internal/ | the #94 defect is systemic locally |
| **Commits** | 4/606 recent subjects reference an issue; fleet-sync noise dominates | near-zero-signal surface |

**The cross-cutting law** (the programme's strongest single finding): every class of
hand-restated fact converged on **23–61% rot within months, with zero renames involved**.
Rename fragility — the first-pass's headline disease — is the *smaller, latent* half;
**derivation without regeneration is the active defect engine.** And the honest split the
critique demanded **[ADJ-10]**: ~350 statements are *objectively false today* (false against
manifest or remote under current doctrine); the ~3,500 "latent-fragile" instances and the
96.5% L3 union-defect headline are *standard-relative* (they count doctrine-compliant badges
and pins), and are cited here only as conversion scope, never as objective defect mass.

### c.2 Highest-leverage fixes, ranked

1. **Make-safe pre-pass (immediate, 6–10 ATU)**: correct the ~350 false statements in place
   — pins to the ratified branch-until-tag rule or the real tag, floors to manifest values,
   6+2+2 wrong product names, 272 old-org URLs, ~30 broken links, 40 dead DocC links + 9
   Core mentions, evict the scratch clone, add the missing LICENSE. Bug-class under existing
   doctrine; doubles as the dump-package plumbing's integration test.
2. **Template supersession + deletion sweep**: badges, floors, counts, bare tables, dead
   Community blocks — one recorded doctrine change, one bot sweep, plus a shape deny-list
   validator so the classes cannot return.
3. **Authored product coverage** for the ~60–90 packages with gaps (#80's predicate
   report-only until cohorts convert; findings exact-owner).
4. **Complete-or-delete 213 placeholder catalogues** + SPI publish gate on the marker; swap
   72 name-addressed badges to path-addressed; module-existence validation.
5. **Coordinate hygiene**: inventory-keyed old-org/renamed-repo rewrite; qualify the 157
   bare `#N` in active record trees (Research's 1,049 exempted by ruling as archival);
   never-reclaim rule (free governance); resolution-audit predicate.

---

## (d) Enforcement architecture

### d.1 The real hosts **[ADJ-2]**

The first-pass's "swift-linter / central policy path" conflated two systems. Verified
against source: **swift-linter is AST-only by construction** — rules are pure functions over
a SwiftSyntax tree, the walker includes only `**/*.swift` and excludes `**/*.docc/**`, no
API access. It can host **none** of the markdown/GitHub predicates. The actual hosts, all
existing:

| Host | Input domain | Already owns | Fixture model |
|---|---|---|---|
| `.github` central validator fleet (~45 Python validators, `validators-manifest.yaml`, `validate-base.yml`) | repo files (README, DocC, metadata) | README-001…151 families, DOC-020…101 (incl. one content regex — the precedent) | `fixtures/<rule>/{fail,pass,edge}` repo-shaped; run errors on silent SKIP; weekly + on-edit |
| Records reconciler (`reconcile-project-invariants.yml`) | live GitHub objects via GraphQL | ProjectV2 row invariants; title-match discovery (label-trap retired); dry-run; report-only + 2 ratified mutations | scanner unit tests |
| Workspace | manifests (`dump-package` — the sanctioned no-second-parser route), inventory (`Workspace.json`), receipts | doctor verdict discipline (`ok/finding/unmeasured/notApplicable`); byte-compare drift precedent (xcworkspace sync; scheme preflight); lint digest receipt = #90's digest byte-for-byte | Swift Testing suites |
| Issue forms | authoring time | bug/change/documentation forms; **no Goal form exists** | n/a (needs reconciler back-stop — GitHub never re-validates edits) |
| Skills | judgment | readmes.md constitution (incl. its self-admitted validator/prose divergence), docc.md, github skill; enforceability taxonomy (decidable/judgeable/open; decidable shells) | honest-voice rules |

**G1 — the open host ruling**: new markdown predicates can extend the Python fleet
(cheapest, established) or grow the Swift `RepositoryPolicy` tool (#42 direction, satisfies
the no-new-Python rule). This is an *open* choice in taxonomy terms; the migration timeline
must not proceed as if it were settled. Principal ruling required (§g).

### d.2 Predicate catalogue

| Predicate | Owner | Decidability / FP | Fixtures | Status |
|---|---|---|---|---|
| P1 display-name Project refs without adjacent coordinate | reconciler | decidable shell; **medium FP → report-only permanently, precision measured** | bare "admitted to Institute Work" (fires) / #94's amended gloss (silent) / injected GraphQL failure (unmeasured) | new; the detector resolves the live title set — never hard-codes "Institute Work" |
| P2 restatement deny-list (badge shapes, floor prose, platform tables, bare product tables outside any marker) | fleet | decidable shapes; medium FP → scope to family E, exclude fences | live positives exist (swift-rss-standard floors; swift-comparison-primitives table) | new; replaces the consensus's generated-block drift check as the primary D1 instrument under deletion-first |
| P2b product coverage | **#80 (exists, open)** | decidable via dump-package; unmeasured-not-clean | per #80's text | do not create a second owner; report-only until cohorts convert |
| P3 pin currency (README-164) | fleet (remote tags) | decidable; low FP (1 known grep FP class) | injected tag lists | designed, never implemented — build it |
| P4 volatile inventories in Goal bodies | reconciler | checkbox-in-Goal-body decidable near-zero FP; count-regex high FP → judgment | #94's dated frozen count as negative control | new |
| P5 record-grammar conformance | goal.yml form (write) + reconciler (read) | decidable **only after ratification**; prospective-only | conformant/nonconformant bodies | new; grammar must exist first |
| P6 DocC restatement + placeholder marker + SPI gate + module existence | fleet (DOC-1xx family) | shape classes decidable; exclude tutorials/Resources | existing DOC fixture suite | extends live precedent |
| P7 coordinate well-formedness (cross-repo `owner/repo#N`, algorithm-qualified digests, repo-scoped SHAs) | reconciler (records) + fleet (docs); commits = skill-only | format decidable; intent not | string-level | new; commit enforcement deferred (G7) |
| P8 reference resolution audit (cited URLs/SHAs/digests resolve; redirect rot) | fleet, scheduled | decidable; fail-closed on network | resolvable/dead/unreachable | new (prior-art: persistence is a service, services are verified) |
| P9 identity-sentence equality (README first line vs metadata description) | fleet | decidable equality; **warn-only** (judgment owns wording) | L2's 65 divergents | new, cheap |

Cross-cutting rules: every predicate reports `unmeasured`, never clean, when it could not
measure (doctor/lint verdict discipline); enumeration only from `Workspace.json`, never tree
walks; deny ratchets key on **in-repo machine state** (`readme.schema` flag + markers),
never on issue/label state — the first-pass's "denies once a repo's sweep issue closes"
repeats the retired label-trap and names a host (swift-linter) that cannot observe issues at
all.

### d.3 What stays judgment

Per the enforceability taxonomy, with the decidable shell named in each sentence (the
enforcement file's §3 drafts are adopted): reader-value of prose (nothing adjudicates it;
the deny-list checks shapes, not worth); when a gloss alone suffices inside a record that
defined the coordinate; supersession completeness ("nothing checks that an amendment
preserves history — that is the author's obligation"); the five-disposition semantic review
(#79's ratified rule) in the judgment wave; complete-vs-delete for the ~30–50
mixed-content DocC catalogues. Skills must keep readmes.md's "Where the check and the text
disagree" section truthful as predicates land, and the github skill's stale three-types
sentence is corrected in the same wave (the Goal type is live).

### d.4 Build gaps

G1 host ruling (S, **a ruling not code**); G2 *reduced*: markers + install-snippet
generation only if canary adopts it (S–M, was M–L); G3 reconciler sections P1/P4/P5 (M); G4
goal.yml (S); G5 README-164 (S–M); **G6 generic content-addressed receipt type in Workspace
(M) — the single highest-leverage shared build**: one implementation serves #79's final
receipt, this Goal's cohort receipts and rollback map, and future #94-class receipts; G7
commit checks (deferred); G8 wave-0 content fixes (S); **G9 (new): `///` doc-comment
coverage instrument (S–M)**; **G10 (new): canary agent-eval protocol** — task battery over
converted vs legacy repos, success/tokens/turns, defined before W2 or the canary gate is
theater.

---

## (e) Migration programme

Costs in agent-task units (ATU: one bounded agent session; calibration: #94 measured 471
repos and filed 145 issues in a day). Deletion-first revisions applied.

| Wave | Content | ATU | Exit criteria |
|---|---|---|---|
| **W-1 make-safe** (starts now, disposition-independent) | correct ~350 false-today statements; evict scratch clone; frozen measurement comment; no HOLD-lane repo touched | 6–10 | zero statements provably false at receipt revision |
| **W0 doctrine** | dedicated assessment → Goal filed/accepted; **supersessions recorded** (readmes.md badge/floor mandates; github-skill stale types); readership + #79-scope + G1 + **mutation-channel** rulings; goal.yml; skill sentences; 3 remaining org profiles; Draft C filed principal-authored | 10–15 | assessment accepted; supersessions merged; channel policy recorded |
| **W1 instruments** | deny-list validators, README-164, module-existence, placeholder/SPI gate, badge form, old-org ban — all report-only; reconciler P1/P4/P5; `readme.schema` field; **G6 receipt type + enumeration**; #80 predicate report-only; G9 `///` audit; G10 eval protocol | 14–24 | every predicate fleet-wide report-only with {fail,pass,edge} fixtures green; G6 used by ≥1 real receipt |
| **W2 canary** | 10–20 repos across layers incl. hard cases; instrumented agent-eval (deleted vs legacy; snippet variants); **one rehearsed revert** | 5–8 | zero drift findings; no task regression; revert receipted; design sign-off — **the Goal's abort gate** |
| **W3 layer sweeps L1→L2→L3** | per sealed cohort: sweep issue → two-commit bot push (deletions ∥ any marker blocks) → CI settle → G6 receipt → deny for that cohort keyed on `readme.schema` → residual issues (est. 25–45 repos) | 15–28 | 100% converted+flagged+receipted or named residual; no unknown surface; #80 green on converted cohorts |
| **W4 records + DocC** | qualify 157 active-tree bare refs; Research-exemption ruling; complete-or-delete 213 placeholders; SPI gate live; reconciler deny for new records | 12–20 | zero placeholder text on any shipped surface |
| **W5 judgment + seal** | five-disposition adjudication over ~110 ≥p75-length READMEs + ~25 authored catalogues (per-line removal test; semantic-review receipts); identity alignment; final page-complete audit; cohort seal (post-#79-gate); closing report | 22–36 | terminal disposition per page; final content-addressed receipt; close `completed` |
| coordination | cohort issues, heartbeats, HOLD liaison with #94 lanes | 8–12 | — |

**Roll-up: ≈ 80–150 core; central ~110–120; envelope 85–160 with contingency** (consensus
plan was 100–190; deletion-first saves the G2 heavy build and its ×1.5–2 sensitivity).
Nominal ~6 weeks (aggressive 3, conservative 10); the long poles are principal-acceptance
cycles and CI settling. Layer order is now reasoned, not asserted: L1 first (existing
injection pipeline, most uniform, exercises scale), L2 second (constitution supersession
settled + multi-org coordinates + spaced paths), L3 last (5 template generations, 915-line
outliers → highest residuals).

**Sensitivity (ranked)**: (1) mutation channel — per-repo PR + review instead of bot push
adds +100–150 ATU, nearly doubling the programme; the bot-push precedent exists (gitignore
canon ×197); settle in W0. (2) Judgment-wave scope — full-fleet adjudication +40–60 ATU;
the ≥p75 + authored-catalogue scoping holds the line. (3) Residual rate 5–10% assumed; L3
heterogeneity could push 15%. (4) Research exemption saves 10–20 ATU at near-zero value
lost.

**Half-converted-state guards** (the 40/60 point): the **`readme.schema` flag in
`metadata.yaml`** (machine-readable regime marker, set only by the sweep, schema-enforced)
is the load-bearing guard the first-pass lacked; warn→deny ratchet keyed on that flag +
cohort receipts; canonical template + validators flipped *before* the first cohort so
exemplar-copying agents mint the new form; make-safe first so the legacy half is
true-but-inconsistent rather than false; audits enumerate from Workspace.json + flag; four
trust rules for agents mid-conversion live one-per-home (flag; skills sentences —
facts from `dump-package`, tags from remote never local, README pins advisory until flag=2;
never hand-edit inside markers; receipts are the conversion authority). Per-README banners
rejected (2×450 touches for information the flag carries).

**Rollback**: two-commit discipline (deletions vs marker injections separately revertable);
versioned, digest-stamped markers delimit any generated content; **G6 receipts record
per-file pre-conversion blob SHAs — restore is a mechanical checkout, not archaeology**;
judgment wave strictly last so mechanical rollback never touches authored edits; one revert
rehearsed at canary. Worst credible case (design abandoned at ~200 conversions): 2–4 ATU +
a day of CI churn; the irreversible set is empty while the rules hold. Note the asymmetry
that favors the standard: generated-or-deleted wrongness is uniform and fixable at one
point; hand-rot is 41 different wrongs.

**Verification traps** (from the audits' own failures, binding on the executing programme):
local checkouts lie twice (0 tags fetched in 449/451 repos; content lags remote — the
standards profile was already converted remotely while local looked stale) → every receipt
pins remote revisions; paths contain spaces → NUL-delimited tooling only; product names
only from evaluated manifests (naive greps produced 34 false positives on the
String-constant DSL); `Workspace.json` is the only enumeration authority (build sandboxes
contain 170 phantom ci.yml copies); run-level CI conclusions, not check rollups.

---

## (f) Disposition

### f.1 The recommendation

**File one new Goal (Draft A), gated by its own dedicated assessment, with the canary/abort
gate inside it. Do not evolve #79. Do not split into two Goals. Do not defer.** **[ADJ-9]**

Why this beats each alternative:

- **vs evolve-#79**: not because the anti-scope-injection sentence is a wall (it is
  supersedable text, as the critique showed), but because of **portfolio mechanics**: #79 is
  Critical, activated, 12/13 children closed, and closeable the moment #80's predicate lands
  and its final audit runs over its cohort. Amending it to absorb an 85–160 ATU fleet
  programme would couple the portfolio's most mature convergence to its largest new
  workload, destroy the finite-episode property that makes its receipts meaningful, and
  retroactively blur what its acceptance accepted. The programme's own precedent (#94
  consumes #90 as "a prerequisite … not a child objective") exists for exactly this shape.
- **vs two-stage (#90→#94 shape)**: strictly more honest about unmeasured benefit, but its
  entire advantage is captured by the **receipted canary gate with a named abort path
  inside the single Goal** — at zero extra principal-acceptance cycles, which are the
  measured long pole. If the canary shows no benefit, the Goal closes `not planned` with a
  linked successor and the landed doctrine/predicates survive as ordinary exact-owner work
  — which is exactly what stage-1 of the two-stage plan would have left behind.
- **vs no-Goal (doctrine as Tasks)**: right for the doctrine layer in isolation (the #68
  precedent is real, and the Goal therefore makes its doctrine children executable
  immediately) — but a ~450-page conversion with sealed cohorts, receipts, rollback, a
  judgment wave, and #79/#80/#94 lane interactions is precisely what Goal machinery and
  portfolio visibility exist for.
- **vs defer**: loses under every hypothesis to the make-safe pre-pass (the estate is
  actively lying to whoever reads it) and to the live doctrine conflicts (readmes.md
  mandates what the evidence condemns) that need resolution regardless.

### f.2 The #79 boundary, precisely

- **#79 owns**: its sealed activation cohort — the surfaces of its activation findings and
  13 children (reproducer index, programme-state model, census snapshots, seven org-profile
  inventory removals, fail-closed scan leg, #80) — through its pending page-complete
  controlled audit and final receipt. It **never touches the package estate** (verified: no
  package README among its children).
- **#80 stays #79's child and is satisfied as designed**: the predicate exists fail-closed
  and fixture-backed on the evaluated manifest; findings are exact-owner work; it is
  report-only until cohorts convert; generated READMEs are neither built nor required —
  #80's recorded rejection of them stands. This dissolves the deadlock orderings (predicate
  before conversion → hand-patching wasted; fleet-green-coverage reading → circular wait).
- **The new Goal owns**: the authoring/identifier/grammar standard and its supersessions;
  all fleet page conversion; the record-tree qualification; the DocC placeholder programme;
  every new predicate in §d.2.
- **The gate, rewritten** **[ADJ-3]**: sealing of the new Goal's conversion cohort waits on
  **#79's closure, or an accepted principal ruling pinning the scope of #79's final audit —
  whichever is earlier**; nothing else waits. The first-pass's "consumes its final
  content-addressed receipt" gated on a phantom (verified: no sealing receipt exists), and
  its "a page needing both cures is remediated under #79 first" was vacuous for the fleet
  (#79 will never remediate those pages) — both clauses are gone from Draft A.

### f.3 Every must-answer attack, quoted and answered

**Attack 1 — the trilemma.** *"The #80/generation/agents-only trilemma. Choose: delete-not-
generate under the assumption; or admit mixed readership and drop the assumption as
premise; or gate on canary evidence. Any answer forces a recorded supersession of #80's
rationale and readmes.md — the standard contradicts ratified doctrine and must say so."*
**Conceded and resolved — mostly exit (i), with (iii) as the guard** **[ADJ-1]**:
deletion-first for derived facts; authored coverage satisfies #80 *as designed*, so **#80 is
not superseded** (the attack's forcing clause is half-defused: only readmes.md's badge/floor
mandates need recorded supersession, and W0 records them); the canary still compares
deleted-vs-legacy before any sweep. One correction to the attack: it claimed *any* answer
forces superseding #80 — the deletion-first path specifically does not, because #80's
philosophy (authored naming + mechanical coverage check, generation rejected) is exactly
what ships.

**Attack 2 — the #79 audit-scope fork.** *"No sealing receipt exists; pin what #79's
page-complete audit covers before writing any gate that consumes its 'final receipt', and
fix Draft A's vacuous 'both cures under #79 first' clause."* **Conceded in full.**
Re-verified this session: two comments, no receipt; the body's "seals the eligible cohort"
is genuinely ambiguous against the assessment's broad eligible-surface enumeration. Both
defective clauses removed from Draft A; the fork is presented to the principal (§g.1) with
a recommendation: pin the cohort to the activation findings' surfaces, routing fleet-scale
findings to the new Goal — the reading consistent with #79's sealed-remediation-set
sentence, its closed children, and its closeability. If the principal instead reads the
eligible cohort as fleet-wide, the disposition flips to evolve-#79 by force — the
recommendation exists precisely to prevent that incoherence.

**Attack 3 — honest reframing.** *"Fleet stale-derived-content + new standards layer, not
'sibling disease'. This changes the assessment's evidence section and the Goal's name, not
the outcome."* **Conceded** **[ADJ-4]**. By mass, ~99% of measured defects are #79's
disease class; the genuinely new identifier disease is small (5 display-name refs, 6
renamed-repo links, 157 active-tree bare `#N`) but structural. Draft A's objective now
says this in its first paragraph, and cites #79's recurrence rule as the *authority for*
a new assessed Goal rather than pretending disjoint diseases.

**Attack 4 — commitment granularity.** *"Single Goal with a receipted canary/abort gate vs
two-stage #90→#94 shape. Either is defensible; chartering fleet conversion with no benefit
measurement and no abort path is not."* **Conceded in substance**: Draft A now contains the
canary gate as a first-class Gate with the abort path named (`not planned` + assessed
successor; doctrine survives). Single-Goal is chosen over two-stage for acceptance-latency
reasons (§f.1); the attack's real demand — never charter the fleet sweep on unmeasured
benefit — is met.

**Attack 5 — G1 + mutation channel.** *"G1 host ruling + mutation channel (±100–150 ATU)
settled in W0, acknowledging the Python-fleet vs. Swift-direction (#42) collision — these
two decisions swing the programme's cost more than every other line item combined."*
**Conceded**: both are named W0 children in Draft A and open questions to the principal
(§g.3–4); the W1 timeline is explicitly conditional on G1.

**Attack 6 — identifier rule repairs.** *"Adopt never-reclaim + resolution auditing;
minimal grammar core, prospective-only, versioned; price the pair rule (define-once-per-
record); treat org names as the highest-blast-radius renameable coordinate."* **Adopted
verbatim** (§b.1 P4, §b.2 rule 2, §d.2 P8). On the ordering sub-attack ("gloss-first …
the first-pass's 'coordinate first' is asserted, not derived"): resolved as order-is-style,
pairing-is-substance **[ADJ-5]** — the predicate checks the pair, both orders conform, and
the canonical rendering leads with the semantic handle for lexical anchoring.

**Attack 7 — decouple the assumption.** *"It isn't ratified, is empirically leaky, and
isn't needed for 90% of the standard; either ratify a weaker 'agent-first' form on GitHub
or stop citing it as binding."* **Conceded** **[ADJ-7]**: the standard is re-derived from
measured drift + context economics; the weak form ("agents primary; never depend on human
memory or human-only rendering") is what the assessment ratifies; the readership question
goes to the principal (§g.2).

**Attack 8 — Draft C timing.** *"After ratification, principal-authored, or reconciler-flag
only."* **Conceded** **[ADJ-11]**: the sentence is true today, principal-accepted as
written, and one bullet from a correct #68 citation; an agent-side edit now would be
enforcement before ratification and pure churn on a stable record. Draft C ships in the
drafts file with the filing instruction "principal-authored (or delegated), after W0
ratification; until then reconciler P1 flags it report-only". Its exhibit value is retained;
its urgency claim is dropped. The cure prescription also now covers future comments
(the defect is wider than the one sentence — gh-live discrepancy 5).

**Attack 9 — start make-safe now.** *"The ~350 false statements are the only part of this
programme that is urgent under every hypothesis."* **Adopted as W-1**, Bug-class,
disposition-independent, per #94's "independently executable now" precedent. It also
de-risks the half-converted state at its dangerous end (false → absent-or-correct).

**Attack 10 — instrument the benefit.** *"Define the canary agent-eval protocol; audit
`///` coverage — so the next Goal in this family argues from measurement, not mechanism."*
**Adopted as G9/G10** (§d.4, W1). Conceded plainly: no controlled study links README format
to agent task success; the benefit side of this programme rests on mechanism plausibility
plus measured *cost* of the status quo (the 23–61% rot is real regardless). The canary is
where the benefit claim gets its first measurement, and the abort path is what makes that
honest.

### f.4 Adjudication index

[ADJ-1] Deletion-first over generation (overrides migration's central costing; agrees with
critique; #80 verbatim text is the tiebreaker). [ADJ-2] Enforcement hosts per enforcement
agent; first-pass §3 discarded. [ADJ-3] #79 gate rewritten; migration's live finding 1
over first-pass. [ADJ-4] Honest disease framing per critique. [ADJ-5] Pair-rule order is
style; pairing is substance. [ADJ-6] Commit trailers non-transferable (squash culture);
literature §2.8 deferred. [ADJ-7] Agents-only decoupled to the weak form. [ADJ-8] DocC
programme is placeholders, not hash links; estates over first-pass. [ADJ-9] Single Goal
with canary gate over two-stage. [ADJ-10] 96.5% headline split into objective (~350) vs
standard-relative (~3,500). [ADJ-11] Draft C deferred to post-ratification,
principal-authored. [ADJ-12] Minimal record grammar with grandfather clause over full
section-list ratification.

---

## (g) Open questions genuinely requiring the principal

1. **The #79 audit-scope fork (blocking for Draft A's gate).** #79's pending "first
   content-addressed, page-complete controlled audit seals the eligible cohort". Does the
   eligible cohort mean (i) the activation findings' surfaces (recommended — keeps #79
   closeable; fleet findings route to the new Goal) or (ii) all assessment-enumerated
   eligible surfaces fleet-wide (which balloons #79 and forces the evolve-#79 disposition)?
2. **Readership ruling.** Is external/human adoption (SPI rendering, social previews,
   "public alpha") a near-term objective? The deletion-first standard is safe either way,
   but the answer decides whether SPI/social surfaces are in-scope investments or
   maintained as-is, and whether the weak agent-first form is the right ratification.
3. **G1 enforcement host.** Extend the Python validator fleet (cheapest, established,
   collides with the no-new-Python rule) or grow Swift `RepositoryPolicy` (#42 direction,
   more build)? A ruling, not code.
4. **Mutation channel.** Bot push (precedented: gitignore canon ×197; keeps the programme
   at ~85–160 ATU) or per-repo PR + review (+100–150 ATU)? The single biggest cost lever.
5. **Draft C authorship.** Principal-authored amendment after ratification (recommended),
   delegated, or reconciler-flag-only forever?
6. **Research-tree exemption.** Ratify archival status for `Research/` (1,049 bare `#N`
   left as-is; generated index already displaces prose inventories there) — saves 10–20
   ATU at near-zero value lost.

## Source map

Research files (companion files in this directory):
`literature.md` (27 sources, evidence-graded), `prior-art.md` (32 sources, 9 laws),
`gh-live.md` (durable coordinates, verbatim anchors, 6 discrepancies), `enforcement.md`
(5 hosts, P1–P7, G1–G8), `estate-primitives.md` / `estate-foundations.md` /
`estate-standards-records.md` (whole-population audits), `migration.md` (costed waves,
2 fresh live findings), `critique.md` (steelmen, V1/V2, 10 must-answer attacks).
First-pass under test: an earlier working draft of this synthesis, superseded by this
report and not durably stored.
Companion drafts: `agent-first-presence-drafts.md` (same directory as this report).
