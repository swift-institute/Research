# Adversarial critique: the agent-first presence consensus

Produced 2026-07-30 by the adversarial critique agent. Read-only throughout (gh GET only; no
Institute files touched). Inputs: the first-pass report, literature.md, prior-art.md, gh-live.md,
enforcement.md, estate-primitives.md, estate-foundations.md, estate-standards-records.md,
migration.md, plus two fresh read-only verifications of my own:

- **V1 — `swift-institute/.github#79` full body and comment census.** #79 has exactly **two
  comments** (assessment `5122723062`, acceptance `5122813499`). **No sealing or controlled-audit
  receipt exists.** Its completion text requires a final controlled audit reporting "no violation
  and no unknown or unmeasured surface" against "the cohort's resulting source revisions", and its
  activation text says "The first content-addressed, page-complete controlled audit seals the
  eligible cohort" — i.e. the seal itself has not happened yet.
- **V2 — `swift-institute/.github#80` full body.** #80's "Alternatives considered" **explicitly
  rejects generation**: "2. Generate complete READMEs from manifests. Rejected because the useful
  descriptions, examples, and grouping are authored documentation." Its outcome requires the check
  to "preserve authored descriptions and allow curated grouping **rather than require a generated
  README**", states that hand tables "often contain useful authored explanations, so removing them
  wholesale would discard reader value", bans "another regex parser", and routes to "the Swift
  policy-engine direction already tracked in #42".

My stance: break the consensus where it is breakable; concede where the evidence holds. Each attack
states what would have to be true for it to win and what in the record supports or undercuts it.

---

## 1. Attacks on the disposition (new Goal, do not expand #79)

### 1.1 Steelman (a): evolve/amend #79

**The honest advocate's case.**

1. **The "sibling disease" framing is partly false.** The first-pass sells the new Goal as curing a
   *different* disease (reference fragility + authoring form) from #79's (fact drift). The estate
   audits demolish this: of the measured defect mass, ~1,400 manifest-restatement blocks with
   23–61% live drift, ~350 provably-false-today statements, and 213 placeholder catalogues are
   **stale derived content — #79's named disease, at fleet scale**. The genuinely new identifier
   disease is tiny by comparison: 5 display-name Project references in local records + 1 sentence in
   #94, 2 renamed-repo link targets in L1, 1 in L2 (vs. 157 bare `#N` in active record trees — the
   one mid-sized identifier class). The new Goal is, by mass, **#79 part 2 (fleet edition)** with a
   standards ratification stapled on. If the disease is the same, the natural owner is the Goal that
   named it — especially since #79's accepted assessment *enumerates READMEs and DocC as eligible
   surfaces*.
2. **The anti-scope-injection clause binds agents, not the principal.** "Later unrelated content or
   policy proposals are new exact-owner work and do not reopen this Goal" is a sentence in a body
   the programme itself amends by dated amendment block (#94's body was amended to reverse its
   admission status). The assessment's "A later broad, finite recurrence would require its own
   assessment rather than reopening #79" requires *an assessment*, and the principal can supersede
   any record. Governance text is a cost, not a wall.
3. **Word-level reading:** the body says later ***unrelated*** content is new work. Fleet README
   drift is *related* content on *enumerated-eligible* surfaces — arguably inside the spirit of #79,
   merely missed by its activation triage.
4. **Cheaper ceremony:** one re-assessment of #79 (a comment) vs. a whole new Goal (assessment +
   filing + admission + its own receipt machinery).

**Why it still loses — but not for the first-pass's stated reason.** The load-bearing argument is
not the textual prohibition (supersedable) but **portfolio mechanics**: #79 is Critical, activated,
12/13 children closed, and closeable as soon as #80 lands and its final audit runs. Amending it to
absorb a 100–190 ATU fleet programme couples the portfolio's most mature convergence to its largest
new workload, destroys the "finite episode" property that makes #79's receipts meaningful, and
retroactively muddies what its acceptance accepted. The precedent machinery (#94 consumes #90 as
prerequisite-not-child) exists precisely for this shape. **However**, the attack succeeds against
the first-pass's *framing*: the synthesis must stop calling this a sibling disease and present the
new Goal honestly as "the same disease at fleet scale, which #79 sealed itself away from, plus a
new standards layer." It must also resolve a latent ambiguity my V1 exposes: **#79's page-complete
controlled audit has not run.** When it runs, either (i) its rule set is scoped to the activation
cohort — in which case its final receipt certifies almost nothing the new Goal needs, and "consumes
#79's final receipt and audit implementation" gates on an artifact of near-zero relevant scope — or
(ii) it sweeps eligible surfaces (READMEs included) fleet-wide, in which case it will surface the
~350 false statements as findings and #79 balloons anyway. The consensus never confronts this
fork. **Win condition for (a):** if the principal reads #79's eligible-surface enumeration as
committing #79 to fleet triage, (a) becomes the *forced* outcome, not an option. Probability-
weighted, (a) is wrong but the fork must be answered before Draft A's gate clause is filable.

### 1.2 Steelman (b): no Goal — doctrine in skills + predicates as ordinary exact-owner work

**The honest advocate's case.**

1. **The programme's own precedent for doctrine is Task-scale.** Partitioned authority — arguably
   the most consequential doctrine ratified this month — landed as **Task #68**, closed completed in
   days. Nothing about "reference mutable entities by durable coordinate" is bigger than #68.
   Identifier policy = a few sentences in the github skill + reconciler predicate P1 (report-only) =
   2–4 ATU of exact-owner work. Record grammar = `goal.yml` + reconciler P5 = 2–4 ATU (enforcement's
   own G3/G4 estimates). The #82 correction's assessment ceremony applies to *Goals*; doctrine
   routed as Tasks avoids an assessment cycle entirely, and the workspace context discipline
   already says where doctrine lives (skills hold judgment; deterministic facts in
   Workspace/linter/CI).
2. **A Goal is coordination overhead purchasing coordination value.** For mostly-mechanical
   enforcement (write a predicate, add fixtures, flip report-only), the Goal ceremony (assessment,
   admission, activation, receipts, closure report) is pure tax. The bot already pushes fleet-wide
   without per-sweep Goals (gitignore canon ×197).
3. **Evidence in the record:** enforcement.md's gap table prices the entire enforcement layer at
   S/M items; none needs programme-level sequencing except G2 (generation) — and G2 is only needed
   if generation survives §2.3's attack.

**Why it loses for the conversion, wins for the doctrine.** A ~450-page conversion with sealed
cohorts, receipts, rollback, a judgment wave, and interaction with #79/#80/#94 lanes is exactly
what the Goal machinery exists for: it is finite, observable, fleet-scale, and needs portfolio
visibility (the coordinator's pristine-GitHub mandate). But the attack lands on scope: **the
doctrine and enforcement layer does not need to wait for, or live inside, a Goal.** Draft A partly
concedes this ("Doctrine, template, and enforcement children are executable immediately") — at
which point the Goal's charter value is the conversion episode alone, and the synthesis should say
so plainly. **Win condition:** if the canary (see 1.4) shows fleet conversion doesn't pay, (b)
becomes the whole answer: doctrine + predicates land, conversion never charters, no Goal was ever
needed.

### 1.3 Steelman (c): multiple smaller Goals

The task's variant (identifier-Goal + README-Goal + grammar-Goal) is weak — identifier durability
and record grammar are Task-scale (see 1.2) and three assessment cycles is ceremony cubed. But the
**two-stage variant is the strongest rival to the consensus**: Goal-1 "ratify the standard, land
all predicates report-only, build G2/G6, run the canary with an instrumented agent-eval, seal a
canary receipt" (closeable, ~40–60 ATU); Goal-2 "fleet conversion" chartered **only after** the
canary receipt shows benefit. This is precisely the programme's own **#90 → #94 shape** (baseline
instrument Goal, then fleet-application Goal consuming its receipt) — the consensus cites that
precedent for the #79 relationship while ignoring that it argues equally for splitting *this*
programme. What it buys: the 100–190 ATU fleet commitment is never chartered on unmeasured benefit
(the literature's own §7.5 concedes no controlled study links README format to agent success; the
canary eval is currently an exit-criterion bullet with no protocol). What it costs: a second
assessment/admission cycle (the demonstrated long pole is principal-acceptance latency, not agent
labor) and the risk of a stranded Goal-1. **Win condition:** if the principal weighs
unmeasured-benefit risk above calendar, (c) wins. The single-Goal alternative can neutralize this
only by adding an explicit, receipted canary gate *inside* Draft A with a named abort path
(close `not planned` + separately assessed successor) — which Draft A currently lacks.

### 1.4 Steelman (d): defer — the assumption is doing too much work

1. **The binding assumption is unratified by the programme's own rules.** "ONLY AI agents read
   Institute code and documentation" appears in boot context and a memory note. The workspace
   CLAUDE.md: "Durable rulings belong in that domain's canonical ruling store, not in boot
   context." gh-live's overlap scan found **no issue owning agent-first anything** — so the
   assumption motivating the standard is itself an un-owned, un-ratified claim. A Goal whose
   assessment leans on it must first ratify it — and ratifying it as stated may be impossible,
   because:
2. **The estate contradicts it.** The org runs `generate-social-preview.yml` (social cards exist
   for humans sharing links); 53 L3 + others opt into Swift Package Index, which renders docs to
   human browsers (16 placeholder catalogues live there today); the org profile says "Public
   alpha"; migration worries about "external copy-paste graphs". Either these surfaces are dead
   weight to be deleted under the assumption, or human/external readers exist and the assumption is
   false at the margin. Nobody in the stack resolves this.
3. **Premature conversion:** converting ~450 READMEs before enforcement exists is the first-pass's
   own named anti-pattern, and L3's five coexisting template generations are the fossil record of
   exactly that failure mode.

**Why full deferral still loses.** (i) The make-safe pre-pass (~350 false-today statements, 6–10
ATU, Bug-class under existing doctrine) is justified under *any* assumption — the estate is lying
to whoever reads it. (ii) The doctrine conflicts (readmes.md badge/pin mandates vs. the deletion
direction) exist now and need resolution regardless. (iii) Most of the standard survives without
the assumption: literature §7.2 concedes the recommended form is human-legible anyway, and the
semantic-identifier evidence shows agents do better on human-legible text. **The correct
disposition of (d) is not deferral but decoupling: strike "agents are the only readers" as a load-
bearing premise and re-derive the standard from measured drift + context economics, which carry it
fine.** The only decisions that genuinely need the strong assumption — deleting human-comfort
surfaces (badges, Community sections, quick-starts) — are independently justified by measurement
(badges: 434 copies of an unfalsifiable claim; Community sections: 100% dead) or must wait for the
canary. What would have to be true for (d) to win outright: evidence that human/external adoption
is a near-term programme objective. The public-alpha + SPI + social-preview investments are weak
but real evidence in that direction; the synthesis should ask the principal rather than assume.

### 1.5 Verdict on the disposition

The first-pass conclusion (one new Goal) survives, but **every one of its four supporting arguments
needs repair**: the sibling-disease framing is half-false (1.1); the scope-injection clause is a
cost argument, not a prohibition (1.1); the #79-receipt gate points at a nonexistent artifact of
unresolved scope (V1); and the #90→#94 precedent it cites cuts both ways (1.3). The strongest
surviving form: one Goal, honestly framed as fleet-scale stale-derived-content convergence + a new
authoring/identifier standard, with doctrine/enforcement children executable immediately, an
explicit receipted canary gate before any layer sweep, and the #79 boundary settled by pinning what
#79's final audit actually certifies.

---

## 2. Attacks on the authoring standard itself

### 2.1 The record grammar: ossification and the n=3 problem

- **Premature standardization.** The grammar's evidence base is three Goal bodies, of which **#94
  already deviates** ("extra sections", per enforcement §0.5). Ratifying a headings-set from n=3
  with a 33% deviation rate freezes a convention before it has been exercised. The de-facto grammar
  *evolved* (#94 added what it needed) — exactly the adaptability a frozen schema kills.
- **Retroactive violation manufacture.** A ratified exact-set check makes the accepted, principal-
  signed #94 non-conformant on day one. The standard needs an explicit prospective-only /
  grandfather clause; no draft has one.
- **Who versions it?** Draft A says `.github` owns the standard but names no versioning mechanism.
  Prior-art supplies the fix (CloudEvents minimal core; self-described version; declared BACKWARD
  compatibility; reserve-don't-recycle) — the synthesis should adopt prior-art's four upgrades
  verbatim and ratify a **minimal required core only** (kind, owner coordinate, status, grammar
  version), not the full #79/#90 section list.
- **Weak guarantee anyway:** GitHub never re-validates edited bodies; forms shape first-write only;
  the reconciler back-stop is report-only. Cost small, benefit small — right-size the ceremony.

### 2.2 The durable-identifier rule: durability is weaker, and dearer, than advertised

- **GitHub issue numbers are conditionally durable.** Issue-level transfer renumbers (old URL
  redirects); repo rename survives only until name reclaim; **Actions `uses:` never redirects**;
  node IDs rotated format in 2021. `owner/repo#N` is therefore a *slower-rotting display name at
  the org/repo level*, not an absolute coordinate — and the estate is **multi-org (13+ orgs)**, with
  a repo (`swift-rfc-2387`) that already moved orgs leaving stale install coordinates behind. The
  actually load-bearing mitigations are prior-art's **never-reclaim rule and resolution auditing**
  — both absent from the first-pass. Only content digests are unconditionally durable, and digests
  are unresolvable without a locator.
- **The pair rule has a token bill nobody priced.** "the Institute portfolio Project (org
  `swift-institute`, ProjectV2 number 2, currently titled 'Institute Work')" is ~20 tokens where
  "Institute Work" is 2. Applied to every reference in every record, the standard inflates exactly
  the surfaces the literature says degrade with length. Mitigation nobody proposed: **define once
  per record** (a definitions/coordinates block, legal-drafting style), gloss-only thereafter.
- **Ordering may be backwards for retrieval.** NoLiMa says attention needs literal/lexical anchors;
  agents grep "Institute Work", not `PVT_kwDODzfg4s4BenOf`. Gloss-first with coordinate
  parenthetical serves retrieval at equal durability; prior-art's `name@coordinate` single-token
  rendering agrees. The first-pass's "coordinate first, display name only as gloss" is asserted,
  not derived.
- Does the standard trade readability for durability? With the pair rule, no — the trade is
  readability+durability for **tokens and authoring friction**. That trade must be priced per
  reference frequency, not mandated uniformly.

### 2.3 Generated READMEs: the consensus's deepest incoherence (strongest attack in this critique)

Three ratified or binding positions collide:

1. **The binding assumption:** only agents read; agents have `workspace package dump-package`, the
   manifest, and the symbol graph. Literature P5: "prefer code over descriptions" — the manifest
   *is* the spec.
2. **#80 (ratified, open, #79's child):** every product must be named in the README; generation
   **explicitly rejected** ("useful descriptions, examples, and grouping are authored
   documentation"); "preserve authored descriptions … rather than require a generated README";
   hand tables carry "reader value" (V2).
3. **The consensus cure (first-pass + estates + migration):** build G2 — the programme's single
   biggest instrument (8–15 ATU ×1.5–2 sensitivity) — to *generate* product/platform/install
   tables into READMEs, plus a perpetual drift-check tax (every manifest edit now needs a
   regeneration commit, fleet-wide, forever).

Under the binding assumption, **deletion strictly dominates generation** for manifest facts: an
agent with `dump-package` gains nothing from a generated restatement, and the token-economics
literature scores every restated table as distractor mass. The only readers a generated table
serves are humans on github.com/SPI without a checkout — readers the assumption says don't exist.
The consensus therefore builds its most expensive machinery to serve readers it denies having, in
order to satisfy a predicate (#80) whose recorded design philosophy (authored tables + mechanical
coverage) it simultaneously overturns. Three coherent exits, none chosen by the consensus:

- **(i) Agents-only, taken seriously:** delete derived tables; satisfy or supersede #80 with "one
  canonical link to the manifest/generated docs counts as coverage"; G2 shrinks to an install-
  snippet generator or nothing; save 20–40 ATU and the perpetual tax.
- **(ii) Mixed readership, admitted:** keep #80's philosophy (authored + coverage-checked), or
  generate — but then strike the agents-only premise from the assessment and stop justifying
  deletions with it.
- **(iii) Evidence first:** let the canary agent-eval compare deleted vs. generated vs. legacy
  READMEs before committing the fleet.

Also unmeasured by anyone: the literature's claim that **inline `///` at the declaration site is
the primary agent surface** — no estate audit counted doc-comment coverage at all. The programme
may be optimizing the second-most-important surface while the first is dark. And #80's own text
supplies the counter-evidence to "delete human-shaped prose": authored explanations around tables
are reader value per a ratified record; estate-primitives agrees ("the highest-value README content
observed is exactly what is NOT derivable"). The literature's verdict is *prune restatement, keep
overview/judgment prose* — the synthesis must prevent the deletion program from over-rotating into
prose-stripping, which the evidence does not support.

### 2.4 The #94 micro-fix (Draft C): lawful in form, premature in substance

- **Form:** a dated amendment block is the programme's lawful edit form; not a supersession
  violation per se. The prior-art (ADR/PEP) model is satisfied.
- **Substance, four problems.** (i) The sentence is **true today** and sits one bullet from a #68
  citation that routes to the durable authority — the defect is latent-stylistic, not live. (ii)
  The text was **principal-accepted as written** ("accepted as written; paused"); an agent-side
  amendment edits an accepted disposition record to conform to a standard that **does not exist
  yet** — enforcement before ratification, on the principal's own words. (iii) It is **incomplete
  as a cure**: comment `5126676306` (the actual admission ruling) and #79's acceptance ecosystem
  also say "Institute Work" bare (gh-live discrepancy 5); a rename still strands the comments, so
  the amendment buys near-zero rename-safety. (iv) It adds a second amendment block to an
  already-amended body — churn on a stable record, against the determinism/no-gratuitous-churn
  principle the same standard imports from Manus. **Disposition:** fold into wave 0 *after*
  ratification, ideally as a principal-authored amendment; or drop it and let reconciler P1 flag it
  report-only forever. As a motivating exhibit it remains excellent; as an immediate edit it is
  the standard violating its own spirit to advertise itself.

### 2.5 Draft A drafting defects (filable-blocking)

1. **Gate on a phantom:** "consumes its final content-addressed receipt and audit implementation"
   — no such receipt exists (V1), no sealing audit has run, and its eventual scope is the 1.1 fork.
2. **Vacuous/deadlock clause:** "A page needing both cures is remediated under #79 first" — #79's
   remediation set contains zero package READMEs (migration live finding 1); read literally the
   clause waits on work #79 will never do.
3. **Unclosable completion:** "every mechanically recognizable class is enforced fail-closed" —
   enforcement.md shows P1/P4 are permanently report-only (medium/high FP). Completion must admit
   "or ratified report-only with measured precision".
4. **Missing entirely:** the readmes.md/#80 supersessions (the standard *contradicts ratified
   doctrine*: README-008 mandates the Installation block, readmes.md mandates the status badge the
   standard deletes — these are supersession decisions, not cleanup); the canary/abort gate; the
   never-reclaim rule; resolution auditing; the multi-org coordinate surface; the mutation-channel
   decision (the single biggest cost lever, ±100–150 ATU).
5. **Wrong enforcement host throughout** (first-pass §3): swift-linter is AST-only Swift, excludes
   `*.docc/**`, has no API access — it can host none of the named classes. The real hosts (Python
   validator fleet + reconciler) exist and are never named; and the host *choice* is itself an open
   ruling (G1) with a recorded Swift-direction precedent (#42, via #80's text) colliding with the
   no-new-Python rule.

---

## 3. Internal contradictions across the research stack (named)

1. **Denominators disagree everywhere.** Tasking: ~390 roots. Estates: 451 local (450 unique; L2 is
   108, not 28). #94 remote measurement: 471. L1 contains a scratch clone inflating counts. No two
   documents share a population, and the reconciliation is a guess ("gap ≈ name-reservation repos").
2. **First-pass vs. enforcement on hosts:** "swift-linter / central policy path" vs. "swift-linter
   can host none of these." Fatal to first-pass §3/§4 as written; enforcement is right (verified
   against `Lint.Source.Parsed` requiring SwiftSyntax).
3. **First-pass vs. migration on #79's reach:** "both cures under #79 first" vs. "#79 will never
   touch the package estate" (GraphQL-verified 13 children). Migration is right.
4. **First-pass "sibling disease" vs. the estates' mass:** ~99% of measured defects are #79's
   disease class (stale derived content), ~1% the new identifier class. The new Goal's honest name
   is not "sibling".
5. **Literature vs. estates/enforcement on commit messages:** "the highest-durability store the
   programme has … the natural place for invariants and receipts" vs. fleet history is bot-sync
   noise (4/606 subjects reference an issue) **and history will be squashed at release** — squash
   destroys the append-only log, so the durability-bonus premise is false *in this programme*.
   Deferring G7 (migration, enforcement) is right; the literature's §2.8/§4.5 recommendation should
   be marked non-transferable until squash culture changes.
6. **Literature vs. first-pass on prose:** P1 "under-specify prose" vs. literature's own carve-out
   (task records demonstrably fail under-specified; trigger-condition prose carries measured lift)
   vs. #80's ratified "authored explanations are reader value". The deletion program and the
   over-specification duty pull opposite directions and the first-pass never states the split.
7. **First-pass DocC worry vs. measured DocC reality:** disambiguation-hash fragility (17 instances
   fleet-wide, 0 in L2) vs. 213 placeholder catalogues and 84/90 L2 stubs. Emphasis inverted
   (estate-standards says so explicitly).
8. **readmes.md constitution vs. the standard:** the ratified README constitution *mandates* what
   the standard deletes (status badge, Installation block, pin forms) and admits its own validator
   diverges from its prose. First-pass claims the authoring standard is "genuinely new" /
   unowned; in fact a constitution exists and the work is supersession. Estate-standards and
   enforcement both flag it; the first-pass and gh-live's overlap scan (issues only) missed it.
9. **#80 vs. generation:** ratified rejection of generated READMEs (V2) vs. the consensus cure
   (generated blocks). Unacknowledged by every document in the stack.
10. **Agents-only assumption vs. SPI/social-preview/public-alpha investments** (§1.4) — and vs.
    literature §7.2's hedge ("agent-first should never be implemented as human-hostile").
11. **Enforcement's "extend the Python fleet (cheapest)" vs. workspace CLAUDE.md's no-new-
    Python/shell rule vs. #80/#42's recorded Swift policy-engine direction.** Flagged as G1 but the
    migration timeline (W1, days 5–16) proceeds as if G1 were settled.
12. **gh-live's citation correction vs. the first-pass:** the scope-injection sentence is in #79's
    *body*, not its assessment — a mis-citation inside a programme whose subject is citation
    discipline. Cosmetic, but the synthesis should model the discipline it prescribes.

---

## 4. Evidence-quality audit

**Solid (measured against ground truth):** the drift rates (24% product tables, 26% product
coverage, 47%/23% L3 floor claims, 61% L3 pins, 100% L1 `from:` pins dead, 7/51 L2 pins) — all
computed against manifests or remote tags; #79/#80/#90/#94 verbatim anchors (gh-live); #79's
13-child set (GraphQL); the swift-linter input-domain facts (read from source); V1/V2 above.

**Directional only:** every ATU figure (the unit is "one bounded agent session", uncalibrated
beyond one analogy to #94's day); the 6-week calendar; the 5–10% residual rate; the canary
agent-eval (no protocol, no metric — currently an aspiration, not an instrument).

**Inflated or circular:** the 96.5% "defective READMEs" headline — the union includes status
badges and branch pins that are **mandated or permitted by current ratified doctrine**; counting
policy-compliant content as defect presupposes the standard under debate, then cites the count as
its justification. The honest split: ~350 false-today statements (objective) vs. ~3,500 "latent-
fragile" instances (standard-relative). **Single-source vendor claims:** the 80%-system-prompt
number (one blog post, harness-specific, correctly scoped by the literature agent); markdown-90%-
cheaper (one practitioner post, echoed); Lore trailers (unvalidated preprint — and non-transferable
here per contradiction 5). **Unverified in the whole stack:** inline `///` doc-comment coverage
(the literature's declared primary agent surface — never audited); whether #79's triage receipt
exists anywhere off-issue; the 471-vs-451 reconciliation; any empirical link between README format
and agent task success (conceded open by literature §7.5 — the entire benefit side of the 100–190
ATU cost rests on mechanism plausibility, not measurement).

---

## 5. Ranked list: attacks the synthesis MUST answer

1. **The #80/generation/agents-only trilemma (§2.3).** Choose: delete-not-generate under the
   assumption; or admit mixed readership and drop the assumption as premise; or gate on canary
   evidence. Any answer forces a recorded supersession of #80's rationale and readmes.md — the
   standard contradicts ratified doctrine and must say so.
2. **The #79 audit-scope fork (V1).** No sealing receipt exists; pin what #79's page-complete audit
   covers before writing any gate that consumes its "final receipt", and fix Draft A's vacuous
   "both cures under #79 first" clause.
3. **Honest reframing of the disease (§1.1/contradiction 4):** fleet stale-derived-content + new
   standards layer, not "sibling disease". This changes the assessment's evidence section and the
   Goal's name, not the outcome.
4. **Commitment granularity (§1.3):** single Goal with a receipted canary/abort gate vs. two-stage
   #90→#94 shape. Either is defensible; chartering fleet conversion with no benefit measurement
   and no abort path is not.
5. **G1 host ruling + mutation channel (±100–150 ATU) settled in W0**, acknowledging the
   Python-fleet vs. Swift-direction (#42) collision — these two decisions swing the programme's
   cost more than every other line item combined.
6. **Identifier rule repairs (§2.2):** adopt never-reclaim + resolution auditing; minimal grammar
   core, prospective-only, versioned; price the pair rule (define-once-per-record); treat org
   names as the highest-blast-radius renameable coordinate (multi-org estate).
7. **De-couple the standard from the agents-only assumption (§1.4)** — it isn't ratified, is
   empirically leaky, and isn't needed for 90% of the standard; either ratify a weaker "agent-first"
   form on GitHub or stop citing it as binding.
8. **Draft C timing (§2.4):** after ratification, principal-authored, or reconciler-flag only.
9. **Start the make-safe pre-pass now** (disposition-independent, Bug-class, 6–10 ATU): the ~350
   false statements are the only part of this programme that is urgent under every hypothesis.
10. **Instrument the benefit** (define the canary agent-eval protocol; audit `///` coverage) so the
    next Goal in this family argues from measurement, not mechanism.

---

## 6. Honest probability-weighted view of the best disposition

| Disposition | P | Note |
|---|---|---|
| **One new Goal, substantially amended** (honest framing per §1.1; doctrine/enforcement children immediate; explicit receipted canary gate + abort path; #79 gate rewritten per V1; readmes.md/#80 supersessions in W0; G1 + mutation channel settled at assessment) | **0.45** | The first-pass disposition survives only in this repaired form |
| **Two-stage Goals** (#90→#94 shape: standard+instruments+canary Goal, then conversion Goal consuming its receipt) | **0.30** | Strictly more honest about unmeasured benefit; costs one acceptance cycle |
| **Hybrid:** doctrine/identifier/grammar as Task-scale exact-owner work (no assessment ceremony), single Goal for conversion only | **0.12** | Matches the #68 precedent for doctrine; weakest on portfolio visibility of the standard itself |
| **Evolve/amend #79** | **0.06** | Textually possible, mechanically unwise; becomes forced only if the principal reads #79's eligible-surface enumeration as fleet commitment (the §1.1 fork) |
| **Defer everything** | **0.02** | Loses to the make-safe pre-pass and the live doctrine conflicts under every assumption |
| Other (e.g. conversion-by-bot with no Goal at all) | 0.05 | — |

Under all dispositions: start the make-safe pre-pass immediately; do not file Draft A as written
(five blocking defects, §2.5); do not execute Draft C before ratification; and treat the agents-
only assumption as a hypothesis to be ratified-or-weakened, not a premise already in force.
