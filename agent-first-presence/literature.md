# Literature review: context engineering and agent-readability for the Institute's GitHub presence

Produced 2026-07-30 by the deep-research literature agent. Read-only with respect to GitHub; no Institute files touched. 24+ distinct primary sources fetched and analyzed (list in §8). This document stress-tests the first-pass report (an earlier working draft, superseded and not durably stored) against the literature; verdicts in §6.

**Evidence grades used throughout:**
- **[E] Empirical** — controlled measurement, peer-reviewed or reproducible benchmark.
- **[V] Vendor-reported** — a lab or vendor states a number from internal evals; plausible, not independently reproduced.
- **[P] Practitioner-converged** — multiple independent builders report the same lesson; no controlled study.
- **[F] Folklore** — widely repeated; no evidence of effect, or evidence against.

---

## 1. The principal-designated prior art, precisely

Source: *The new rules of context engineering for Claude 5 generation models* (claude.com/blog). Section headings: "Unhobbling Claude", "Then and Now", "Applying this to your context", "Try simplifying".

Actual claims:

1. **Constraint removal at scale [V]:** "We removed over 80% of Claude Code's system prompt for models like Claude Opus 5 and Claude Fable 5 with no measurable loss on our coding evaluations." (Internal evals; system prompt of a harness, not repository documentation.)
2. **Then→Now table (six shifts):** rules → judgment; examples → **design interfaces**; all-upfront → **progressive disclosure**; repetition → simple tool descriptions; memory-in-CLAUDE.md → **auto-memory**; simple specs → **rich references**.
3. **Progressive disclosure mechanics:** move verification/review detail into skills the model "selectively call[s]"; use deferred tool loading (ToolSearch) so definitions enter context only when needed.
4. **Context architecture:** system prompt = product framing; **CLAUDE.md = "lightweight repo description; emphasize 'gotchas' over obvious information"**; skills = team-specific opinions; references = @-mentioned files, **"prefer code over descriptions"** (test suites and functions as higher-fidelity specs than prose).
5. **Newer models tolerate less scaffolding:** conflicting guidance is handled better without explicit constraint text; capable models need interfaces more than examples.
6. **Auto-memory:** manual CLAUDE.md memory entries are unnecessary; the harness saves relevant memories itself.
7. Tooling: `claude doctor` automates simplification of system prompts, skills, CLAUDE.md.

Two scoping notes that matter for the Institute: (a) the 80% number is about a *harness system prompt*, not about issue records or READMEs — it licenses pruning of standing instructions, not of task specifications; (b) "auto-memory" is per-account harness state — it does not replace a *shared* source of truth for a fleet (see §7.3).

---

## 2. Findings by theme

### 2.1 Context is a scarce, degrading resource — the empirical core

- **Context rot [E]** (Chroma, 18 models incl. GPT-4.1, Claude 4, Gemini 2.5, Qwen3): "model performance varies significantly as input length changes, even on simple tasks." Distractors (topically related but wrong content) hurt disproportionately; degradation accelerates when needle–question semantic similarity is low; "what matters more is how that information is presented."
- **Lost in the Middle [E]** (Liu et al., TACL 2023): U-shaped position effect; "performance can degrade significantly when changing the position of relevant information," worst mid-context, "even for explicitly long-context models."
- **NoLiMa [E]** (2025, 13 models ≥128K claimed): when questions and needles share minimal lexical overlap, **11 of 13 models fall below 50% of their short-context baseline at 32K**; GPT-4o drops 99.3% → 69.7%. Cause: "the increased difficulty the attention mechanism faces in longer contexts when literal matches are absent."
- **RULER [E]** (NVIDIA, 17 models): despite ≥32K claims, "only half of them can maintain satisfactory performance at the length of 32K" — claimed context ≫ effective context.
- **Distraction [E]** (Shi et al., ICML 2023, GSM-IC): "model performance is dramatically decreased when irrelevant information is included"; instructing the model to ignore irrelevancies partially mitigates.
- **Knowledge conflict [E]** (Xie et al. 2023/24): models are "highly receptive to external evidence even when that conflicts with their parametric memory, given that the external evidence is coherent and convincing," **and** show "strong confirmation bias" when context partially matches parametric memory. Direct consequence: a stale-but-plausible statement in a record will be believed and propagated.
- **Anthropic synthesis [V/P]:** context is "a finite resource with diminishing marginal returns" (attention budget); goal is "the smallest set of high-signal tokens that maximize the likelihood of some desired outcome." Claude Code docs: "LLM performance degrades as context fills"; bloated CLAUDE.md files "cause Claude to ignore your actual instructions."
- **Failure-mode taxonomy [P]** (Breunig via LangChain): context **poisoning** (hallucination enters context), **distraction** (context overwhelms training), **confusion** (superfluous context influences output), **clash** (parts of context disagree).

**Implication:** every token on a surface an agent must load is a cost paid on *every* task that touches the surface; redundant, stale, or ambiguous tokens are not neutral filler but active degraders (distraction, clash, confirmation bias).

### 2.2 Progressive disclosure and just-in-time retrieval

- **Anthropic (effective context engineering) [P/V]:** the field is moving to "just in time" context: agents "maintain lightweight identifiers (file paths, stored queries, web links, etc.)" and load data at runtime — "progressive disclosure … allows agents to incrementally discover relevant context through exploration."
- **Agent Skills [V]:** codified three-level loading — L1 name+description preloaded ("just enough information … to know when each skill should be used"), L2 full SKILL.md on demand, L3+ linked files navigated as needed; therefore "the amount of context that can be bundled into a skill is effectively unbounded." Guidance: "When the SKILL.md file becomes unwieldy, split its content into separate files"; keep mutually-exclusive paths separate to save tokens.
- **Retrieval vs. long context [E]** (Li et al., EMNLP 2024): "when resourced sufficiently, LC consistently outperforms RAG in terms of average performance," but RAG's "significantly lower cost remains a distinct advantage"; Self-Route (model decides per query) retains LC-comparable quality at much lower cost. Reading: neither "stuff everything in" nor "retrieve everything" wins universally; route by need — which is exactly what progressive disclosure implements for repository surfaces.
- **Cognition (counterweight) [P]:** "Share context, and share full agent traces, not just individual messages" and "Actions carry implicit decisions, and conflicting decisions carry bad results." Fragmenting context across agents/surfaces fails when decisions interlock. Disclosure boundaries must match decision boundaries — split what is independent, keep together what must be decided together.
- **Manus [P]:** the file system as "unlimited in size, persistent by nature, and directly operable" external memory; compression must be **reversible** — "storing URLs instead of pages, paths instead of full document contents." Also: KV-cache hit rate is "the single most important metric" (input:output ≈ 100:1); stable append-only prefixes; no timestamps in stable prefixes; deterministic serialization; recitation (rewriting todo.md) to pull goals into recent attention; keep errors in context so the model updates its beliefs.

### 2.3 What the labs say agents' instruction files should contain

- **Claude Code best practices [V/P]** — the sharpest per-line test in the literature: "For each line, ask: *'Would removing this cause Claude to make mistakes?'* If not, cut it." Include: commands the agent can't guess, style rules that differ from defaults, testing instructions, repo etiquette, project-specific architectural decisions, environment quirks, "common gotchas or non-obvious behaviors." Exclude: "anything Claude can figure out by reading code," standard conventions, detailed API documentation ("link to docs instead"), "information that changes frequently," file-by-file codebase descriptions. Also: instructions are advisory; **hooks are deterministic** — "Unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens" (enforcement belongs in machinery, not prose).
- **AGENTS.md [P]** (OpenAI/Google/Cursor/Factory et al., now Linux Foundation-stewarded): "a dedicated, predictable place to provide the context and instructions to help AI coding agents"; **used by over 60k open-source projects**; nearest-file-wins nesting; explicit rationale that README stays human-focused while agent files hold operational detail. Suggested content converges with Claude's list: overview, build/test commands, style, testing, security, **commit/PR guidelines**.
- **GitHub Copilot repository instructions [V]:** supports `.github/copilot-instructions.md`, path-scoped `*.instructions.md` with `applyTo` globs, and reads `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` natively; guidance: document bootstrap/build/test/run/lint step sequences, keep it "no longer than 2 pages," "not task specific."
- Convergence: three independent vendors specify the same genre — short, operational, non-obvious, command-centric, layered by directory proximity. This genre is *standing rules*, distinct from task records (§2.5).

### 2.4 Machine-readable documentation conventions: real vs. folklore

- **Markdown beats HTML for agent consumption [P, strong]:** Fern: "Markdown reduces token consumption by roughly 90% compared to HTML"; a reference page "consumes ~10,000 tokens as HTML" vs "~1,000 tokens as Markdown." Stripe ships `.md` for every docs URL ("Append `.md` to any docs.stripe.com URL"), plus an MCP server and a machine-readable skills index (`/.well-known/skills/index.json`). Anthropic's own docs serve `llms.txt` and instruct agents to "Fetch the complete documentation index at: https://code.claude.com/docs/llms.txt". GitHub-native markdown (READMEs, issues) is already in the winning format.
- **llms.txt as a crawler standard [F]:** proposal (Jeremy Howard, 2024-09-03) is coherent — curated H1+blockquote+sectioned link lists, an "Optional" section droppable under context pressure — but as of late 2025/2026 "no major AI company has formally adopted LLMs.txt"; "no evidence that any major large language model actually uses it when crawling"; Google states it is unnecessary for its AI surfaces. **However**, llms.txt as a *directed entry-point index* — a file an agent is explicitly pointed at — is exactly how Anthropic and Stripe use it, and that usage is sound. Verdict: adopt the *concept* (curated index at a well-known location that boot context points to); expect zero passive/crawler benefit.
- **Single source of truth as industry practice [P]:** Fern: one canonical spec generates all artifacts so "everything updates together"; language-filtering to cut irrelevant examples. LogRocket/Document360 echo: human-only-optimized docs cause agents to "hallucinate parameters that don't exist."

### 2.5 Task specification quality — where under-specification demonstrably fails

- **SWE-bench Verified [E]:** OpenAI + 93 professional annotators screened 1,699 SWE-bench samples: **38.3% flagged for underspecified problem statements**, **61.1% for unit tests that could unfairly reject valid solutions**; severe cases discarded to produce the 500-task Verified set. This is the strongest direct evidence that **issue-record quality is a first-order determinant of agent success** — vague issue bodies made tasks unsolvable regardless of agent capability.
- **Anthropic multi-agent research system [V]:** "simple, short instructions" for subagents caused duplication and misalignment; the fix was task descriptions with "an objective, an output format, guidance on the tools and sources to use, and clear task boundaries." Also: "token usage by itself explains 80% of the variance" in performance; tool-description refinement alone yielded 40% faster task completion; "bad tool descriptions can send agents down completely wrong paths."
- **Claude Code guidance [V]:** "The most useful specs are self-contained: they name the files and interfaces involved, state what is out of scope, and end with an end-to-end verification step that proves the feature works." Plus the verification doctrine: "Give Claude a check it can run… Without a check it can run, 'looks done' is the only signal available."
- **Claude 5-generation model guidance [V]:** long-horizon work should get "the complete task specification up front in one well-specified turn"; ambiguous prompts revealed progressively "reduce token efficiency and sometimes performance."

**Synthesis: the prune-vs-specify split.** The literature licenses *pruning standing rules* (2.3) and simultaneously demands *over-specifying task records*: objective, scope boundary, acceptance/verification criteria, output format, pointers to sources. These are different genres with opposite failure modes.

### 2.6 Identifiers, links, and durability

- **Link rot [E]** (Pew, 2024): "38% of webpages that existed in 2013 are not available today"; 25% of all 2013–2023 pages inaccessible; 21% of government pages and 23% of news pages contain ≥1 broken link; "54% of Wikipedia pages contain at least one link in their 'References' section that points to a page that no longer exists." Deep links are a wasting asset; anything meant to be read for years must not depend on them resolving.
- **Semantic identifiers beat opaque ones for model precision [V]** (Anthropic, writing tools for agents): avoid "low-level technical identifiers (for example: `uuid`, `256px_image_url`, `mime_type`)"; "merely resolving arbitrary alphanumeric UUIDs to more semantically meaningful and interpretable language … significantly improves Claude's precision in retrieval tasks by reducing hallucinations." Also: return "only high signal information"; Claude Code caps tool responses at 25,000 tokens; concise-vs-detailed response formats (72 vs 206 tokens) matter.
- **Reconciliation (important for P4):** durability and semantic legibility are *both* required, and they are different axes. A durable coordinate (org+number, SHA, digest) survives renames but is opaque — models cannot attend to it semantically, cannot guess it, and (for digests) cannot resolve it without a locator. A display name is legible but breaks on rename. The literature-supported pattern is the **pair**: durable coordinate as the load-bearing reference, stable semantic gloss alongside as the attention/retrieval handle. Digests are verification anchors, not retrieval keys — every digest needs an adjacent resolvable pointer (Manus's "reversible compression" is the same principle: keep the path/URL that re-expands the reference).
- **NoLiMa's corollary [E]:** retrieval degrades without *literal/lexical* anchors. Consistent, exact, greppable strings (canonical spellings of package names, issue coordinates written the same way everywhere) are not pedantry; they are what makes long-context retrieval and `grep` both work.

### 2.7 Memory and long-horizon state

- **MemGPT [E-ish]:** OS-style memory hierarchy (main vs external context, self-editing via function calls) validates the general architecture of small-working-set + durable external store.
- **Anthropic context management [V]:** memory tool + context editing improved agentic-search performance **39%** over baseline; context editing alone **29%**; in a 100-turn eval context editing avoided context exhaustion "while reducing token consumption by 84%." Memory is file-based, client-side, persistent across conversations.
- **Anthropic long-horizon patterns [V/P]:** compaction preserving "architectural decisions, unresolved bugs, and implementation details while discarding redundant tool outputs"; structured note-taking (NOTES.md) persisting across resets; subagents returning "condensed, distilled summary" (1,000–2,000 tokens) to the coordinator; before context limits, agents "summarize completed work phases and store essential information in external memory."
- **Fleet reading:** for a many-agent programme, the "external memory" that matters is *shared and durable* — i.e., GitHub records. Harness auto-memory (§1) is per-account and invisible to peers; it cannot be the programme's memory. GitHub-as-SSOT is the multi-agent analog of NOTES.md, and the same curation rules apply to it (summarize decisions, discard stale tool-output-grade detail).

### 2.8 Commit messages and git history as an agent surface

- **Git history is a designated retrieval source [V]:** Claude Code best practices literally trains users to prompt "look through ExecutionFactory's git history and summarize how its api came to be" — history is expected agent context.
- **Lore preprint [P, 2026-03]:** names the "Decision Shadow" — reasoning, constraints, rejected alternatives lost when commits capture only diffs, a loss that "accelerates" as agents produce and consume code; proposes structured **git trailers** turning commits into "self-contained decision records" (constraints, rejected alternatives, agent directives, verification metadata), "discoverable by any agent capable of running shell commands," no infrastructure beyond git. Not yet empirically validated ("outlines an empirical validation path"). Ecosystem corroboration: QAC, Agent Note, Git AI — multiple independent efforts, all 2025–26, all converging on structured, why-carrying commit messages for agent readers; practitioner observation that messages like "refactor: clean up utils" transmit "near-zero signal" and degrade `git bisect`/`blame`/`log --follow` workflows.
- **Durability bonus:** commit messages are the one Institute surface that is immutable, append-only, rename-proof, offline-available, and version-pinned by construction — the highest-durability store the programme has. That makes them the natural place for per-change invariants and receipts references.

### 2.9 Interfaces over prose

- **SWE-agent [E]:** introduced the agent-computer interface (ACI) concept; "interface design affects the performance of language model agents"; a purpose-built ACI (concise feedback, guardrailed editing, repo navigation) drove SWE-bench 12.5% pass@1 SOTA at the time. Interfaces, not exhortations, changed outcomes.
- **Designated post [V]:** "design interfaces" over examples; "prefer code over descriptions" — the manifest, typed products, and tests *are* the spec.
- Caveat: interfaces still need *trigger-condition* documentation. Tool/skill descriptions stating **when** to use them give measurable lift (multi-agent post: 40% faster completion after description refinement; Claude 5 guidance: prescriptive "call this when…" descriptions raise should-call rates). "Interfaces over documentation" means "mechanism over restatement," not "no prose": the irreplaceable prose is intent, trigger conditions, and traps.

---

## 3. What actually degrades agent performance — consolidated evidence table

| Degrader | Evidence | Grade |
|---|---|---|
| Sheer input length, even on easy tasks | Context rot (18 models); RULER (half fail at 32K); NoLiMa (11/13 below 50% baseline at 32K) | E |
| Mid-context placement of key facts | Lost in the Middle (U-shape) | E |
| Topically-related-but-wrong content (distractors) | Context rot; GSM-IC ("dramatically decreased") | E |
| Stale-but-coherent statements | Knowledge-conflict: models adopt coherent external evidence; confirmation bias on partial matches | E |
| Internally conflicting records | "Context clash" failure mode; Cognition principle 2 (conflicting implicit decisions) | P/E |
| Redundant restatement / bloated instruction files | "Bloated CLAUDE.md files cause Claude to ignore your actual instructions"; 80%-removal result | V |
| Underspecified task statements | SWE-bench Verified: 38.3% of tasks flagged; short subagent briefs → duplicated/misaligned work | E/V |
| Opaque identifiers without semantic handles | UUID→name resolution "significantly improves … precision … reducing hallucinations" | V |
| Missing lexical anchors (inconsistent naming) | NoLiMa mechanism (attention needs literal matches) | E |
| Broken/rotten deep links | Pew (38%/25%/54% figures); agents burn turns on dead ends | E (rot) / P (agent cost) |
| Vague or wrong tool/interface descriptions | "completely wrong paths"; 40% completion-time delta | V |
| Volatile tokens in stable prefixes (timestamps, counts) | Manus KV-cache economics (100:1 input:output; 10× cost delta) | P |

---

## 4. Implications for each Institute surface

### 4.1 Issue and Goal bodies (the record grammar)
1. **Self-containment with acceptance criteria is the top upgrade.** Every Goal/Task body should carry: objective, exact-owner scope boundary, out-of-scope statement, verification/completion predicate an agent can run or check, and pointers (not copies) to sources. (SWE-bench Verified; multi-agent delegation; Claude Code spec guidance.) The first-pass report under-weights this relative to identifier hygiene.
2. **Durable coordinate + stable gloss, everywhere a mutable entity is referenced.** `org swift-institute ProjectV2 number 2 ("Institute Work")` — coordinate load-bearing, gloss parenthetical and marked as a gloss. Never gloss-only (#94's defect); never coordinate-only (retrieval-precision evidence).
3. **Position discipline.** Binding contract sections first; current-state pointers and navigation last; nothing normative buried mid-body (Lost in the Middle). A fixed section grammar delivers this for free and doubles as a lexical-anchor scheme (predictable headings = greppable, attendable).
4. **Supersession must be explicit and dated, never silent edit — and never *only* an appended comment.** Stale text left standing is actively believed (knowledge-conflict evidence); a contradiction between body and later comment is a context clash. The amendment pattern (dated block that marks the old text superseded in place, or edits it with an audit note) resolves the clash at the point of reading.
5. **No volatile inventories/counts in bodies** — confirmed both by programme doctrine (#79/#90/#94) and by cache/attention economics; freeze via content-addressed receipts, but always pair a digest with a resolvable locator (§2.6).
6. **Issue forms/templates as structure enforcement** — the literature's "predictable place" principle (AGENTS.md) applied to records; makes the grammar the path of least resistance and machine-checkable.

### 4.2 Package READMEs
1. The Claude Code include/exclude table maps almost one-to-one onto the first-pass README rule and validates it: keep one-paragraph identity, non-obvious judgment ("gotchas"), canonical entry points; delete or generate everything mechanically derivable from `Package.swift` (product/target/platform tables, toolchain floors, pins). Restated manifest facts are the classic distractor + drift risk (swift-rss-standard, swift-comparison-primitives live examples).
2. **Keep exactly one uniform quick-start line** (`workspace package build|test`) — build/test commands are the single highest-value item in all three vendors' instruction-file guidance. Uniformity across 390 repos makes it near-zero drift risk; deeper workflow belongs to the canonical Workspace doc it links to.
3. **README ≠ agent instruction file.** The ecosystem's division of labor (README = identity/routing; AGENTS.md/CLAUDE.md/skills = operational instructions) matches the Institute's existing context-discipline. Do not migrate skill-grade content into READMEs.
4. Apply the per-line test verbatim in the judgment wave: "Would removing this cause an agent to make mistakes?"
5. Repo-relative links and canonical coordinates over deep external URLs (Pew).

### 4.3 DocC catalogues
1. **The primary agent surface is the source itself** — inline `///` comments and the symbol graph, read via files/SourceKit, not rendered HTML. Rationale belongs at the declaration site; `.docc` articles only for cross-cutting rationale that has no single declaration home. (Markdown-over-HTML economics generalize: rendered docs sites are the expensive path for agents.)
2. **Prefer auto-curation.** Hand-curated topic groups restate structure the symbol graph owns (redundancy + drift), and disambiguation-hash links are signature-fragile — the in-repo analog of deep-link rot. Curate only where ordering itself is judgment.
3. Never restate signatures/availability/platform facts in prose (generated truth exists; restatement is the drift vector #79 targets).
4. Skills' three-level model is the right template: catalogue landing = L1 (what/when), article = L2, deep reference = L3 navigated on demand; split rather than grow (Agent Skills guidance).

### 4.4 Org profiles and `.github`
1. Function as the fleet's **L1 metadata / directed llms.txt**: durable scope statement + curated routing to canonical entry points (Workspace, doctrine issues, layer roots). This is the one place the llms.txt *concept* is well-founded, because boot context points agents at it (directed use, not crawler hope).
2. No current-state prose without a date or a pointer to native state ("pending", license status → route to the owning record). Undated status text is a manufactured knowledge-conflict for every future reader.
3. Keep it within the "2 pages / not task specific" envelope the instruction-file genre converges on.

### 4.5 Commit messages
1. **State the why and the invariant changed; reference the owning issue by durable coordinate; reference receipts by digest+locator.** Supported by: history-as-context (Claude Code), Decision-Shadow argument and trailer structure (Lore), near-zero-signal-message critique (practitioner corpus).
2. **Structured trailers are the right mechanism** (native git, greppable, no infrastructure) for machine-readable fields — e.g. `Issue:`, `Receipt:`, `Invariant:`. Mark as [P]: direction is converging, empirical validation pending; adopt the cheap subset (trailers for coordinates/receipts), defer heavyweight protocol adoption.
3. Commit messages are the programme's most durable store (immutable, rename-proof, offline) — treat them as the append-only decision log the other surfaces link into.
4. Per user/global rules: no AI attribution; authorship identity is orthogonal to machine-readability.

### 4.6 Cross-cutting: enforcement over aspiration
"Instructions are advisory; hooks are deterministic" (Claude Code) is the literature's version of the Institute's own rule that deterministic facts belong in Workspace/swift-linter/CI. Every mechanically recognizable class in the authoring standard should land as a linter predicate/CI gate with fixtures, not as prose in a skill. The first-pass report's §3 is fully aligned.

---

## 5. Evidence-backed vs. vendor folklore — summary judgments

- **Evidence-backed:** length/position/distractor/conflict degradation (§2.1); underspecified issues sink agent tasks (SWE-bench Verified); link rot at scale (Pew); interface design moves outcomes (SWE-agent); LC-vs-RAG cost/quality tradeoff (Self-Route).
- **Vendor-reported but consistent and actionable:** 80% prompt reduction; 39%/29%/84% memory & context-editing numbers; 15× multi-agent token multiplier; token-usage-explains-80%-of-variance; 25K tool-response cap; UUID→semantic-name precision gain; include/exclude tables. Treat numbers as directional, mechanisms as real.
- **Practitioner-converged:** markdown ~90% cheaper than HTML; KV-cache stability rules; file-system-as-memory; reversible compression; structured commit protocols (direction, not proof).
- **Folklore:** llms.txt as a passively-consumed crawler standard; any expectation that a repo's prose is read by crawlers rather than by directed, tool-using agents; "more documentation is always safer" (the evidence says the opposite).

---

## 6. Stress-test of the first-pass report

### P1 — "Under-specify prose, over-specify structure": **Supported with a required carve-out.**
Supported for *standing-rule surfaces* (READMEs, skills, boot context) by the designated post, the 80% result, and the prune-tests. **But the literature splits the genre:** *task records* (Goal/issue bodies, subagent briefs) demonstrably fail when under-specified (38.3% SWE-bench flag rate; duplication from "simple, short instructions"; spec-up-front guidance for Claude 5-generation models). P1 as worded risks being applied to Goal bodies, where it inverts. Restate as: **prune restatement everywhere; over-specify contracts (objective, scope, acceptance criteria) in task records; over-specify structure in both.**

### P2 — "Progressive disclosure with canonical entry points": **Strongly supported.**
Three-level skills model, deferred tool loading, just-in-time retrieval, LC-vs-RAG routing, and attention economics all converge. Two refinements: (a) disclosure boundaries must match decision boundaries — don't fragment interlocking doctrine across surfaces that are loaded separately (Cognition); (b) entry-point indexes work when *directed* (org profile, Workspace docs), not as crawler bait (llms.txt evidence).

### P3 — "SSOT per fact; generated views with drift checks": **Supported, now with a mechanism.**
Knowledge-conflict and context-clash evidence explains *why* duplicated mutable facts are worse than absent facts: coherent-but-stale copies are believed and partially-matching copies trigger confirmation bias. Industry SSOT practice (Fern/Stripe) and determinism-for-cache (Manus) corroborate. Nothing contradicts.

### P4 — "Persistent, machine-checkable identifiers": **Supported, materially refined.**
Link rot and rename fragility fully justify durable coordinates; #90's digest pattern is sound. Refinement from the tool-writing evidence: opaque identifiers *alone* measurably hurt model retrieval precision — so the standard should mandate the **pair** (durable coordinate + stable semantic gloss), not merely permit glosses "as parenthetical glosses." Second refinement: digests are verification anchors, not retrieval keys — require an adjacent resolvable locator (reversible compression). Third: consistent canonical spellings are lexical anchors that long-context attention and grep both depend on (NoLiMa mechanism) — the grammar should fix canonical reference spellings.

### P5 — "Expressive interfaces over documentation": **Supported with one guardrail.**
SWE-agent (ACI), "design interfaces," "prefer code over descriptions." Guardrail: trigger-condition prose is part of the interface, not documentation-to-delete — descriptions of *when to use* a tool/skill/package carry measured lift (40% completion-time delta; should-call-rate guidance). The report's "rationale, judgment, non-obvious traps" scope for retained prose is correct; add "trigger conditions / when-to-reach-for-this" explicitly.

### Per-surface rules (§1 table of the report): supported throughout; gaps to add
- Issue/Goal rule: add **self-containment + acceptance criteria** (the largest omission), position discipline, and clash-resolving supersession semantics (§4.1).
- README rule: add the single uniform quick-start line; otherwise confirmed nearly verbatim by the Claude Code include/exclude table.
- DocC rule: add "inline `///` at declaration site is the primary agent surface; articles are the exception" (§4.3).
- Commit rule: add structured trailers as the mechanism; confirmed direction (Lore + ecosystem).
- Org profile rule: confirmed; frame as directed L1 index (llms.txt concept, done right).

### Enforcement placement (§3) and migration (§4) of the report: **Supported.**
Advisory-vs-deterministic evidence backs linter/CI-first; "doctrine and instruments first, pages last" matches the self-healing argument; the judgment wave should adopt the per-line removal test as its adjudication question.

### Disposition (§5, new Goal vs. evolve #79): **Literature-consistent; nothing contradicts.**
The literature distinguishes the failure classes cleanly: *staleness of facts* (#79's disease: drift, knowledge conflict) vs. *fragility of references* (rot, rename breakage) vs. *authoring form* (attention economics, specification completeness). A page can be fact-fresh yet reference-fragile and attention-hostile — independent axes, independent instruments. Bundling a second regime into an activated, closeable Goal would itself manufacture the ambiguity/clash the standard exists to remove. Governance arguments (#79's accepted assessment forbidding scope injection; #94-consumes-#90 precedent; #82 assessment requirement) stand on the record and are untouched by the literature. Draft C (durable coordinate + titled gloss for #94's "admitted to Institute Work") is precisely the P4-refined pairing pattern.

---

## 7. Tensions and open questions

1. **Shuffled-haystack anomaly.** Context rot found retrieval *improves* when haystacks are shuffled (local coherence removed). Do not generalize to authored records: the finding concerns needle retrieval from filler, not instruction-following over structured contracts. Structure and predictable grammar remain justified by position effects, lexical anchoring, and parseability. Flag as a curiosity, not a design driver.
2. **Agent-only readers is ahead of the literature.** Every vendor guide assumes mixed audiences. The Institute's binding assumption is safe because the recommended form (concise markdown, stable coordinates, semantic glosses) remains human-legible — and the semantic-identifier evidence shows models themselves perform better on human-legible text. "Agent-first" should never be implemented as "human-hostile" (digest walls without glosses would hurt the agents too).
3. **Auto-memory vs. GitHub-SSOT.** The designated post's memory shift (out of CLAUDE.md, into harness auto-memory) is about *per-account* convenience state. Fleet coordination state must remain in shared durable records; auto-memory is invisible to peers and to future sessions of other agents. GitHub-as-SSOT is unchallenged — the post actually argues for keeping boot context lean, which strengthens the routing-not-restating design of CLAUDE.md/org profiles.
4. **Cache economics on GitHub surfaces.** KV-cache arguments (Manus) apply to prompts, not to fetched pages; but their determinism corollary (no gratuitous churn, no volatile counts, append-only amendment) applies to any surface agents refetch and diff.
5. **Empirical gaps.** No controlled study measures agent task success against README/issue formats specifically; commit-trailer protocols are unvalidated; the 80%-removal result is harness-specific. Recommendation: treat the standard's predicates as instrumentable hypotheses — the Institute's receipt/audit machinery can measure (e.g., agent-run outcomes before/after conversion waves) rather than trusting priors.

---

## 8. Sources

**Principal-designated:**
1. The new rules of context engineering for Claude 5 generation models — https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models

**Anthropic engineering/product corpus:**
2. Effective context engineering for AI agents — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
3. Claude Code best practices — https://code.claude.com/docs/en/best-practices (redirect from anthropic.com/engineering/claude-code-best-practices)
4. Writing effective tools for agents — https://www.anthropic.com/engineering/writing-tools-for-agents
5. How we built our multi-agent research system — https://www.anthropic.com/engineering/multi-agent-research-system
6. Equipping agents for the real world with Agent Skills — https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills
7. Managing context on the Claude Developer Platform (memory tool + context editing) — https://claude.com/blog/context-management

**Machine-readable docs conventions:**
8. The /llms.txt proposal (Jeremy Howard) — https://llmstxt.org/
9. AGENTS.md — https://agents.md/
10. GitHub Copilot repository custom instructions — https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions
11. Stripe, Building with LLMs (markdown endpoints, MCP, skills index) — https://docs.stripe.com/building-with-llms
12. Fern, Prepare APIs/documentation for AI agent consumption — https://buildwithfern.com/post/prepare-apis-documentation-ai-agent-consumption

**Empirical degradation and long-context literature:**
13. Chroma, Context Rot — https://www.trychroma.com/research/context-rot
14. Liu et al., Lost in the Middle — https://arxiv.org/abs/2307.03172
15. NoLiMa: Long-Context Evaluation Beyond Literal Matching — https://arxiv.org/abs/2502.05167
16. RULER: What's the Real Context Size of Your Long-Context LMs? — https://arxiv.org/abs/2404.06654
17. Shi et al., LLMs Can Be Easily Distracted by Irrelevant Context — https://arxiv.org/abs/2302.00093
18. Xie et al., Adaptive Chameleon or Stubborn Sloth (knowledge conflicts) — https://arxiv.org/abs/2305.13300

**Agents and repositories:**
19. OpenAI, Introducing SWE-bench Verified — https://openai.com/index/introducing-swe-bench-verified/ (direct fetch 403; figures corroborated via search: 93 annotators, 1,699 samples, 38.3% underspecified, 61.1% unfair tests)
20. Yang et al., SWE-agent: Agent-Computer Interfaces — https://arxiv.org/abs/2405.15793
21. Cognition, Don't Build Multi-Agents — https://cognition.com/blog/dont-build-multi-agents
22. Manus, Context Engineering for AI Agents: Lessons from Building Manus — https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus
23. LangChain, Context Engineering for Agents (incl. Breunig failure modes) — https://www.langchain.com/blog/context-engineering-for-agents

**Durability, memory, commit surfaces:**
24. Pew Research, When Online Content Disappears — https://www.pewresearch.org/data-labs/2024/05/17/when-online-content-disappears/
25. Packer et al., MemGPT — https://arxiv.org/abs/2310.08560
26. Li et al., RAG or Long-Context LLMs? (Self-Route) — https://arxiv.org/abs/2407.16833
27. Lore: Repurposing Git Commit Messages as a Structured Knowledge Protocol for AI Coding Agents (preprint, 2026-03-16) — https://arxiv.org/abs/2603.15566

**Secondary/corroborating (surveyed, lighter weight):** Index Lab and Contentful llms.txt effectiveness analyses; Google Search Central position via press coverage; LogRocket "agent-friendly API documentation"; Document360; QAC / Agent Note / Git AI commit-ecosystem posts; betterclaw AGENTS.md guide.
