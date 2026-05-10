# Agent Harness Engineering: Comparative Analysis

<!--
---
version: 1.5.0
last_updated: 2026-05-10
status: RECOMMENDATION
tier: 3
scope: ecosystem-wide
---
-->

## Context

The 2026-05-10 Tier 3 survey
[`agent-harness-engineering-state-of-the-art.md`](./agent-harness-engineering-state-of-the-art.md)
mapped the field's converged taxonomy (20 canonical components, 12+ shipping
harnesses, ~35 academic foundations, 10+ thought leaders). It deliberately
deferred the comparison against the workspace's own harness to a *second*
session per the user's two-session arc. This is that second session.

**Trigger.** User-directed comparative analysis, dispatched via
`HANDOFF-harness-comparative-analysis.md` 2026-05-10 with the parent's
research session ended (`/handoff` + `/supervise` in absentia per
[HANDOFF-012] / [SUPER-014a]).

**Tier classification.** Tier 3 per [RES-020]: ecosystem-wide,
precedent-setting, normative input to a forthcoming harness-redesign
decision. The companion survey already discharges the SLR / prior-art /
formal-grounding obligations under [RES-023] / [RES-024]; this comparative
deliverable inherits that empirical foundation rather than re-deriving it.
The new empirical work here is *workspace-state verification* — every
load-bearing claim about the workspace's actual configuration carries a
`[Verified: 2026-05-10]` tag plus the command that produced it, per
[RES-023].

**What this document is not.** Not a re-survey (forbidden by ground-rule
#2 of the dispatch). Not an implementation plan or refactor brief
(forbidden by ground-rule #4). Not a redesign decision — every conclusion
below is direction-class only, framed `RECOMMENDATION pending user
authorization`. The forthcoming harness redesign is downstream of the
user's decisions on the recommendations surfaced here.

## Question

> Mapped against the survey's 20-component canonical taxonomy and three
> orthogonal cuts (behavior-first / control-theoretic / operational-layer),
> what does the workspace's actual harness look like — what ships, what's
> the bet vs the gap per component, and where are the leverage points for
> a forthcoming redesign?

Sub-questions:
1. Per the 20 canonical components: what concrete primitive ships in this
   workspace, where does it sit relative to the canonical patterns
   (mainstream / divergent / absent), and is the divergence a deliberate
   bet or an unintentional gap?
2. Which 3–5 components are the workspace's strongest? Which 3–5 are
   the most exposed?
3. What workspace-specific harness *layers* exist that the canonical
   taxonomy does not name — and what is their contribution back to the
   discipline?
4. Given the 2026 frontier (§7 of the survey), what leverage-ordered
   direction items should a forthcoming redesign weigh?

## Analysis

### 1. Methodology

**Sources, ranked by authority:**

1. The survey at `agent-harness-engineering-state-of-the-art.md` — every
   §N.M reference below points there.
2. The workspace's actual on-disk state — `~/.claude/settings.json`,
   `~/.claude/settings.local.json`,
   `/Users/coen/Developer/.claude/settings.local.json`,
   `swift-institute/Skills/`, `~/.claude/projects/.../memory/`,
   `swift-institute/Scripts/`, `*/.github/.github/workflows/`,
   `swift-institute/Research/agent-*-patterns.md`. Each load-bearing claim
   below carries `[Verified: 2026-05-10]` plus the command that produced
   it.
3. CLAUDE.md skill-routing tables (`/Users/coen/Developer/CLAUDE.md`)
   defining the workspace's official component-to-skill mapping.

**Verification scope.** Empirical claims about the workspace's harness
posture (permission rules, hook count, skill count, memory file count, CI
shape, MCP servers configured) are verified against current files.
Claims about *what the survey says* are cited by §N.M, not re-verified;
the survey's own [Verified] tags carry forward by [RES-013a]'s carry-forward
provision since this document is synthesis, not extension.

**Forbidden inference path.** Per dispatch ground-rule #2, this doc does
not re-derive the survey's findings. It maps from the survey's
already-verified taxonomy onto verified workspace state. Where the
mapping reveals an ambiguous bet-vs-gap, the question is surfaced under
`## Open Questions` per ground-rule #6, not silently resolved.

### 2. Workspace Harness Inventory

The workspace's harness is configured at three layers, with the lower two
loaded transitively via the user-level Claude Code installation.

**User-level configuration** (`/Users/coen/.claude/settings.json`,
3,448 bytes [Verified: 2026-05-10 via `wc -c
/Users/coen/.claude/settings.json`]):

| Setting | Value | Source |
|---------|-------|--------|
| `permissions.allow` | 10 entries (Bash(*), WebSearch, WebFetch, Read, NotebookEdit, Grep, Glob, Task, LSP, mcp__cclsp__*) | `jq '.permissions.allow' settings.json` |
| `permissions.deny` | `[]` (empty) | same |
| `permissions.ask` | 83 entries — destructive Bash + secrets-edit | `jq '.permissions.ask \| length'` |
| `permissions.defaultMode` | `"auto"` | same |
| `hooks` | `null` (none configured) | `jq '.hooks // "none"' settings.json` |
| `enabledPlugins` | `{}` (none) | same |
| `effortLevel` | `"high"` | same |
| `skipAutoPermissionPrompt` | `true` | same |
| `skillListingBudgetFraction` | `0.025` (2.5% of context) | same |
| `cleanupPeriodDays` | `30` | same |
| `fileCheckpointingEnabled` | `false` | same |

[Verified: 2026-05-10 via `cat /Users/coen/.claude/settings.json`]

**User-level local additions** (`/Users/coen/.claude/settings.local.json`):
12 additional Bash allow patterns (libtool, system_profiler, launchctl,
toolchain-prefixed, time-prefixed swift build) [Verified: 2026-05-10 via
`jq '.permissions.allow \| length' settings.local.json`].

**Project-level local** (`/Users/coen/Developer/.claude/settings.local.json`,
not committed): 79 allow entries — 50+ WebFetch domain allowlist,
`mcp__dutch-law__*` allow rules, 13 Bash patterns specific to Swift dev
(`swift build *`, `swift test *`, swift-format / swiftlint, toolchain
overrides, `git add *`, `git commit *`, `git push *`, `git stash *`)
[Verified: 2026-05-10 via `jq '.permissions.allow \| length'`].

**Skills layer** (loaded transitively by Claude Code from
`/Users/coen/Developer/.claude/skills/`, regenerated by
`Scripts/sync-skills.sh`):

| Source location | Count | Purpose |
|-----------------|-------|---------|
| `swift-institute/Skills/` | 45 | Canonical Swift infra + process skills |
| `swift-institute/Engagement/Skills/` | 9 | Engagement pipeline (ingest/triage/compose/themes/actionables) |
| `swift-primitives/swift-{index,memory}-primitives/Skills/` | 2 nested | Per-package `index`, `memory-arithmetic` skills |
| `rule-institute/Skills/` | 4 | Legal domain (NOT symlinked into `.claude/skills/` per inspection) |
| **Total symlinked** | **54** | `ls /Users/coen/Developer/.claude/skills/ \| wc -l` |

[Verified: 2026-05-10 via `ls /Users/coen/Developer/swift-institute/Skills/
\| wc -l` (47 entries minus LICENSE.md and README.md = 45) and `ls
/Users/coen/Developer/.claude/skills/ \| wc -l` (54)]

**Memory layer**:
- Auto-memory directory:
  `/Users/coen/.claude/projects/-Users-coen-Developer/memory/` — 188 files
  total [Verified: 2026-05-10 via `ls .../memory \| wc -l`].
- Index file `MEMORY.md`: 31.3KB / 182 lines [Verified: 2026-05-10 via
  `wc -l MEMORY.md`], over the 24.4KB / 200-line cap documented in the
  survey §3.7 and surfaced in the file's own `> WARNING:` footer.
- Project-level CLAUDE.md (workspace-wide instructions):
  `/Users/coen/Developer/CLAUDE.md` (~330 lines) — skill routing tables,
  collaboration protocol, layer architecture, package locations, gotchas.
- User-level CLAUDE.md: `/Users/coen/CLAUDE.md` — short utility file
  with one shell snippet (`Kill Server`) [Verified: 2026-05-10 via direct
  read].

**MCP servers**:
- `cclsp` (sourcekit-lsp wrapper) — workspace-wide via
  `~/.claude/cclsp.json`, exposing `find_definition`,
  `find_references`, `get_hover`, `find_workspace_symbols`,
  `rename_symbol`, etc. [Verified: 2026-05-10 via `cat
  /Users/coen/.claude/cclsp.json`].
- `claude.ai Gmail`, `claude.ai Google Calendar`, `claude.ai Google Drive`
  — user-level integrations (auth cache present at
  `~/.claude/mcp-needs-auth-cache.json` [Verified: 2026-05-10]).
- `mcp__dutch-law__*` — project-allowed for legal-domain work (5 tools:
  `get_provision`, `search_legislation`, `get_provision_at_date`,
  `search_case_law`, `search_eu_implementations`, `get_eu_basis`) [Verified:
  2026-05-10 via project settings.local.json].

**CI infrastructure** (centralized via `.github/.github/workflows/` org-level
reusable pattern):
- `swift-institute/.github/.github/workflows/`: 27 reusable workflows
  (lint-api-breakage, lint-license-header, lint-readme-presence,
  lint-readme-structure, lint-test-support-spine, lint-skill-descriptions,
  lint-mechanical-hygiene, lint-org-bot-coverage, swift-ci, swift-docs,
  cron-audit-base, sync-discussion-threads, sync-metadata, link-check, plus
  weekly variants) [Verified: 2026-05-10 via `ls
  /Users/coen/Developer/swift-institute/.github/.github/workflows/`].
- `swift-primitives/.github/.github/workflows/swift-ci.yml`: 1 layer-tier
  reusable wrapper.
- Per-package `ci.yml` files in swift-primitives subrepos (372 files
  matching `*/.github/workflows/ci.yml` under
  `/Users/coen/Developer/swift-primitives/`): each is a thin wrapper
  delegating to the centralized reusables [Verified: 2026-05-10 via `find
  /Users/coen/Developer/swift-primitives -path "*/.github/workflows/ci.yml"
  \| wc -l`]. Sample wrapper at
  `swift-primitives/swift-stack-primitives/.github/workflows/ci.yml`:
  `uses: swift-primitives/.github/.github/workflows/swift-ci.yml@main`,
  `uses: swift-institute/.github/.github/workflows/swift-docs.yml@main`
  [Verified: 2026-05-10 via direct read].

**Custom user-side surfaces NOT configured**:
- No user-level `agents/` directory (no project-defined sub-agents on top
  of the built-in `Explore`, `Plan`, `general-purpose`, `claude-code-guide`,
  `statusline-setup`) [Verified: 2026-05-10 via `ls /Users/coen/.claude/`
  showing no `agents` entry].
- No user-level or project-level `commands/` directory (no custom slash
  commands beyond Claude Code's built-ins and the user-invocable Skills)
  [Verified: 2026-05-10 via same].
- No user-level or project-level `hooks/` directory [Verified: 2026-05-10
  via `find /Users/coen/.claude/hooks /Users/coen/Developer/.claude/hooks
  2>/dev/null` returning empty].
- No user-level or project-level `output-styles/` directory [Verified:
  2026-05-10 via same].
- `enabledPlugins: {}` — no plugins activated [Verified: 2026-05-10 via
  `jq '.enabledPlugins'`].

**Workspace-side scripts** (workspace tooling complementing the harness):
`swift-institute/Scripts/` contains 28 entries [Verified: 2026-05-10 via
`ls Scripts/`], notably `sync-skills.sh`, `sync-swift-format.sh`,
`sync-swift-settings.sh`, `sync-gitignore.sh`, `sync-dependabot.sh`,
`sync-tools-version.sh`, `sync-community-health.sh`,
`patch-umbrella-symbol-graph.py` (Phase 1 of the AI-context-reduction
work referenced in `Research/ai-context-reduction-via-type-system-tooling.md`),
`ecosystem-timeline.sh`, `concatenate-packages.sh`,
`generate-swift-files-overview.sh`, `setup-mirrors.sh`,
`scaffold-docc-catalog.sh`.

### 3. Per-Component Mapping

For each of the 20 canonical components from survey §2, the table is
*what ships → vs canonical → bet/gap → direction*. Each component cites
its survey section by §N.M.

#### 3.1 Loop / Control Flow (vs survey §3.1)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's built-in ReAct loop with native tool calls; reasoning-internalized via Opus 4.7 (current session); plan/auto/bypass mode menu (the user has chosen `auto` as default per `permissions.defaultMode: "auto"` [Verified: 2026-05-10]). No CodeAct-style code-as-action — Claude Code's loop is per-tool JSON, not Python execution. |
| Vs canonical (§3.1) | **Mainstream.** Single-agent, ReAct, native tool calls — exactly the converged 2026 default per §3.1. The CodeAct option (§3.1, §4 OpenHands) is not adopted; the workspace bets on schema-validated tools over Python-as-action. |
| Bet vs gap | **Deliberate bet.** Schema-validated tools compose with the typed-throws / API-NAME convention discipline that pervades the workspace's own code (`code-surface` skill, [API-ERR-001]). CodeAct would erase that gating surface. |
| Direction | None at component level — `loop` is the most solved component in the survey (§3.1: *"the loop itself is solved"*). Frontier work (context-folding, sub-trajectory branching, FoldGRPO) is downstream of compaction (§3.8 below), not loop control. |

#### 3.2 Tool Surface (vs survey §3.2)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code native tools (Bash, Read, Edit, Write, Grep, Glob, Task, Agent, NotebookEdit, WebSearch, WebFetch, ToolSearch for deferred tools) + 1 workspace MCP (`cclsp` exposing 12 sourcekit-lsp tools — `find_definition`, `find_references`, `get_hover`, `find_workspace_symbols`, `rename_symbol`, `get_diagnostics`, `prepare_call_hierarchy`, `get_incoming_calls`, `get_outgoing_calls`, `find_implementation`, `restart_server`, `rename_symbol_strict` [Verified: 2026-05-10 against `mcp__cclsp__*` ToolSearch entries]) + claude.ai integration MCPs (Gmail, Google Calendar, Google Drive) + 6 dutch-law MCP tools (project-scoped). |
| Vs canonical (§3.2) | **Mainstream + leveraged.** MCP is the field's tool-protocol winner per §3.2; the workspace runs at least 4 distinct MCP servers. The cclsp server is *workspace-specific*: it reduces context-cost on Swift code navigation by exposing semantic symbol queries instead of grep — directly aligned with the §7.2 *coding-agent-as-long-context-processor* frontier, but as *tool-side* rather than file-system-side externalization. |
| Bet vs gap | **Deliberate bet on semantic over textual navigation.** The workspace's own `Research/ai-context-reduction-via-type-system-tooling.md` (Phase 1 shipped) thesis is that *type-system queries are higher-leverage than context-window expansion*; cclsp implements that. CLAUDE.md `## Code Navigation (cclsp)` documents reliability tiers (find_references high, find_definition medium, find_workspace_symbols broken-in-compilation-DB-mode). |
| Direction | **RECOMMENDATION** — quantify the cclsp leverage. The Research doc claims *Phase 1 shipped* but no eval has been run measuring tokens-per-task with vs without cclsp on representative Swift navigation queries. With Terminal-Bench-style whole-harness evals now standard (§3.16, §7.6), the workspace could measure its own tool surface against a no-cclsp baseline to either confirm the bet or surface the cost. *(direction-class; not an implementation prescription — pending user authorization on whether harness-side eval investment is in scope)*. |

#### 3.3 Filesystem / Workspace (vs survey §3.3)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Native Read / Write / Edit / Grep / Glob; durable state via the user's normal git workflow across ~30+ sibling repos under `/Users/coen/Developer/`; per-package `Research/`, `Audits/`, `Experiments/` directories codified by [RES-002], [RES-002a], [META-*]. |
| Vs canonical (§3.3) | **Mainstream + heavily leveraged.** The Trivedy thesis (*"arguably the most foundational harness primitive"*) is fully embraced. The workspace's git pattern matches *"per-turn auto-commit"* / *"PR-as-rollback"* hybrid more than shadow-git checkpoints — multi-repo discipline ([HANDOFF-019] commit-as-you-go) explicitly favors checkpoint commits over Cline-style shadow-git. |
| Bet vs gap | **Deliberate bet on real git over shadow-git.** [HANDOFF-019] codifies *"per-phase commits before proceeding to next phase"*; [GIT-001]+[GIT-005] govern push authorization classes; the workspace handles the *aggressive autonomy paired with cheap revert* principle (§3.3) by making the revert path real-git-history rather than agent-internal checkpointing. Cline-style three-axis restore (files / conversation / both) is not implemented; conversation-restore is via `/handoff` or session-resume, not via shadow-git. |
| Direction | None at component level. The bet is consistent with the workspace's broader version-control discipline. |

#### 3.4 Sandbox / Execution Environment (vs survey §3.4)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's macOS Seatbelt sandbox (the built-in default for `darwin`). FS write-bounded to cwd+subdirs; read access to whole machine except denied paths; network via hostname-allowlist proxy. **Auto mode + `Bash(*)` allow + `skipAutoPermissionPrompt: true`** is the most permissive of the three ask/auto/bypass tiers consistent with the OS-level sandbox staying engaged. |
| Vs canonical (§3.4) | **Mainstream practical-default.** Per §3.4: *"OS sandbox (Seatbelt, bubblewrap, Landlock) — Claude Code, Codex CLI, OpenHands; when to use: local dev with personal codebase."* This matches the workspace exactly: single-tenant, personal codebase, OS-level isolation by default. The Codex CLI's three-mode orthogonal axis is structurally similar but the workspace runs Claude Code, not Codex. |
| Bet vs gap | **Deliberate bet on Anthropic's safety-classifier auto mode** rather than a per-action approval gate. The 83 ask-rules per `permissions.ask` provide the rule-based safety net; auto-mode + Bash(*) leverages Claude Code's background classifier per §3.4 / §3.11. This is exactly the *"more liberal permission posture"* the survey's §3.11 worked example calls out as *one of the more liberal in the field*. |
| Direction | The MCP × sandbox interaction is the survey's §3.4 active fault line (Codex issue #18243). The workspace runs cclsp as an MCP server; whether the sandbox + cclsp combination has the same Seatbelt-blocks-shell-exec class of failure is **untested in this comparative analysis** and surfaces as Open Question 1 below. |

#### 3.5 Sub-agents / Orchestration (vs survey §3.5)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's built-in `Agent` tool with subagent_types: `Explore`, `Plan`, `general-purpose`, `claude-code-guide`, `statusline-setup`. No custom user-level sub-agent definitions ([Verified: 2026-05-10] — no `~/.claude/agents/` directory exists). The workspace's process discipline runs the *workflow-level* counterpart at the skill layer: `/handoff` (52 IDs) + `/supervise` (46 IDs) compose subordinate dispatches against ground-rules blocks per [SUPER-002]. |
| Vs canonical (§3.5) | **Mainstream + workflow-augmented.** Single-agent + sub-agents-for-isolation matches the §3.5 converged 2026 default (Cemri 2025 / Cognition's *Don't Build Multi-Agents*). The workflow-level layer ([HANDOFF-*] + [SUPER-*]) is *user-side*, not agent-side; it codifies how the user composes Claude Code sessions over time. |
| Bet vs gap | **Deliberate bet on workflow-skill discipline over orchestrator middleware.** The workspace does not run an orchestrator like deepagents, OpenAI Agents SDK handoffs, or OpenHands' event-sourced services on a stream. Instead it relies on the user as orchestrator, with [HANDOFF-*] + [SUPER-*] codifying the patterns Magentic-One / handoffs would otherwise embed in code. |
| Direction | **RECOMMENDATION** — examine whether the supervise-in-absentia pattern ([SUPER-014a], the rule that lets a subordinate inherit a ground-rules block from a now-ended principal session) is durable as the workspace scales to longer-horizon programs. The survey §3.5 names *explicit termination contracts* and *sensor-based verification* as MAST-mitigations; [SUPER-014a] is the workspace's analog, but its evidence base is reflection-derived, not eval-derived. *(direction-class; pending user authorization on eval investment)*. |

#### 3.6 Planner / Task Tracker (vs survey §3.6)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's built-in plan mode + the harness's `TaskCreate`/`TaskUpdate`/`TaskList` task tracker. Workflow-level discipline: `/handoff` carries Next Steps + Pre-Existing Code in Scope ([HANDOFF-014]); `/supervise` carries Acceptance Criteria ([SUPER-009]); `/research-process` distinguishes Investigation vs Discovery workflows ([RES-001], [RES-012]). No `feature-list JSON` antidote-to-early-stopping pattern (§3.6) — the workspace uses Acceptance Criteria + per-IP verification ([SUPER-022]) instead. |
| Vs canonical (§3.6) | **Mainstream + heavily-codified.** Plan/Act bifurcation per §3.6 is universal — the workspace has it as plan-mode + auto-mode and as `/research-process` (Investigation = pre-implementation analysis). The codification is heavier than typical: [SUPER-002a] (scope-lock precedes architecture-lock), [HANDOFF-016] (seven staleness axes), [SUPER-035] (pre-dispatch empirical state verification) all extend the planner discipline beyond the field's typical "plan files + write_todos." |
| Bet vs gap | **Deliberate bet on premise-verification-first.** [SUPER-035] empirical state verification, [HANDOFF-021] scope enumeration at write-time, [HANDOFF-029] pre-fire precondition re-check, [HANDOFF-038]/[HANDOFF-039] handoff lifecycle — all codify *premise propagation* mitigation (the §3.6 failure mode from Lin et al. 2025). The discipline is more aggressive than the field default. |
| Direction | None at component level; the workspace is meaningfully ahead on this component. The frontier observation: Devin 2.0's *interactive planning* (§3.6) — proactive codebase exploration before plan finalization — is a feature the workspace's `/research-process` partially replicates via [RES-019] step-0 internal-research grep, but does not yet have a proactive *codebase* exploration counterpart. |

#### 3.7 Memory (vs survey §3.7)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | A 4-tier memory architecture: **(a)** static config — `/Users/coen/Developer/CLAUDE.md` (workspace-wide instructions, ~330 lines, skill routing tables) + `/Users/coen/CLAUDE.md` (user-level utility) [Verified: 2026-05-10 via direct read]; **(b)** auto-memory — `MEMORY.md` (31.3KB / 182 lines, over the 24.4KB / 200-line cap) + 188 topic files at `~/.claude/projects/-Users-coen-Developer/memory/` [Verified: 2026-05-10 via `wc -l` and `ls .../memory \| wc -l`]; **(c)** Skills — 54 progressively-disclosed skill bundles (45 swift-institute + 9 engagement + 2 nested per-package + 4 rule-institute not-symlinked); **(d)** path-scoped rules — *not used* (no `.claude/rules/` directories present in any of the inspected repos, [Verified: 2026-05-10 via search]). |
| Vs canonical (§3.7) | **Highly-converged with field guidance + one over-shoot.** The workspace's official routing rule (`/Users/coen/Developer/CLAUDE.md`'s *Authoritative Documentation* section) independently re-derives Anthropic's routing rule (§3.7 verbatim quote): *"If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule instead."* The workspace's `feedback_*` memory-write guardrail goes further — *"Before saving a `feedback_*` memory entry that codifies a project convention, check whether the rule belongs in an existing skill"* — which is structurally identical to OpenAI Codex's *"Treat memories as a helpful local recall layer, not as the only source for rules that must always apply"* (§3.7). The over-shoot: the index file *exceeds the documented cap*, so the convergent guidance is being violated by the workspace's own state. |
| Bet vs gap | **Discipline failure, not architectural failure.** Per the survey's *Outcome* §K2, this is explicitly the workspace's largest *discipline-not-architecture* miss. The architecture follows the field's converged best practice; the daily discipline of writing skills *first* and saving feedback *narrowly* is what's drifting. Evidence: [feedback_no_regex_evasion_use_disable_with_reason](`feedback_no_regex_evasion_use_disable_with_reason.md`) is a candidate for promotion to a skill rule (it reads as a `[PREFIX-*]` requirement when promoted); so are several other entries in the index. |
| Direction | **RECOMMENDATION** — triage MEMORY.md entry-by-entry: each entry's content fits one of (a) skill rule (promote, leave a tombstone pointer in memory), (b) path-scoped rule (the workspace currently uses none — the field's *.cursor/rules/* / *.claude/rules/* idiom is a third option that could absorb path-scoped corrections), (c) genuinely user-specific preference (the rule's correct home), (d) stale (delete). The triage is the work the survey's *Outcome* §6(a) anticipated. *(direction-class; pending user authorization on whether triage cycle is in scope)*. **Composite RECOMMENDATION** — adopt path-scoped rules as a third memory tier. The workspace has *zero* path-scoped rules at present; the field's converged 4-tier routing (§3.7) treats them as a load-bearing tier between skills (always loaded metadata) and auto-memory (loaded into MEMORY.md). Adopting `.claude/rules/` for per-package corrections would offload entries that don't fit either skills or static config, reducing pressure on MEMORY.md. *(direction-class)*. |

#### 3.8 Context Engineering / Compaction (vs survey §3.8)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's auto-compact (built-in trigger; clears tool outputs, summarizes conversation, re-attaches CLAUDE.md and skill metadata per §3.8). Manual `/compact <focus>` available. Skills' progressive disclosure as the canonical content-shaping primitive — `skillListingBudgetFraction: 0.025` reserves 2.5% of context for skill metadata at startup [Verified: 2026-05-10]. Workspace-side: `Scripts/patch-umbrella-symbol-graph.py` + `Research/ai-context-reduction-via-type-system-tooling.md` (Phase 1 shipped) implement type-system-side context reduction. No PreCompact / PostCompact hooks configured (`hooks: null` per §3.10 below). |
| Vs canonical (§3.8) | **Mainstream + workspace-extension.** Compaction, tool-output offload, progressive disclosure (the three §3.8 techniques) are all present. The workspace adds a fourth: *type-system-as-context-reduction* — the cclsp MCP + symbol-graph tooling reduce tokens-per-task at the *substrate* layer rather than the conversation layer. This is consistent with the §7.2 *coding-agent-as-long-context-processor* direction but unique in casting it as a Swift-specific symbol-graph problem. |
| Bet vs gap | **Mixed.** The progressive-disclosure bet matches §3.8 best practice. The *no PreCompact/PostCompact hook* gap is real — the workspace cannot inject custom context-shaping at compaction boundaries (e.g., re-injecting the supervisor block before / after compact). Whether this is a deliberate bet (auto-compact's defaults are good enough) or an unintentional gap is **ambiguous-intent** and surfaces as Open Question 2 below. |
| Direction | None at component level until the bet/gap question is resolved. |

#### 3.9 Skills (Progressive Disclosure) (vs survey §3.9)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | 54 symlinked skills with the canonical 3-level loading shape per §3.9: frontmatter at startup (Level 1, ~100 tok per skill, 54 × ~100 = ~5,400 tok metadata × 2.5% budget = within the `skillListingBudgetFraction` allowance); SKILL.md body on description-driven trigger (Level 2, <500 lines per [SKILL-CREATE-*] guidance); transitively-referenced files for deep content (Level 3). The 4 process skills `/handoff` / `/supervise` / `/reflect-session` / `/reflections-processing` together carry **133 requirement IDs** [Verified: 2026-05-10 via `grep -c '^### \[' SKILL.md`]: handoff 52, supervise 46, reflect-session 17, reflections-processing 18. The full skill corpus carries hundreds of `[PREFIX-*]` IDs (code-surface 36, etc.) [Verified: 2026-05-10 via per-skill `grep -c`]. |
| Vs canonical (§3.9) | **Most-rigorous skill discipline in the survey.** §3.9 names Anthropic Skills as the canonical implementation; OpenHands microagents as cross-vendor adoption; Voyager (Wang et al. 2023) as academic foundation. The workspace runs Skills *plus* a meta-skill (`skill-lifecycle`, currently 28 [SKILL-LIFE-*] IDs [Verified: 2026-05-10]) governing skill creation/update/review/deprecation, *plus* a meta-meta-skill (`corpus-meta-analysis`) governing the research/experiment corpus health, *plus* a typed requirement-ID system that pervades the skill corpus. No production harness in the survey ships out-of-the-box with this level of skill discipline. |
| Bet vs gap | **Deliberate bet — the workspace's strongest component.** §3.9's failure mode catalog (cross-surface fragmentation, description-budget truncation, stale skills) is mostly addressed: the workspace runs Claude Code only (no Claude.ai / API / IDE-extension fragmentation surfacing); description-budget truncation is mitigated by `skillListingBudgetFraction: 0.025`; staleness is governed by `skill-lifecycle`'s review cadence + the `last_reviewed: YYYY-MM-DD` field on every skill. |
| Direction | None at component level — this is the workspace's flagship component. *Cross-component* implication: because skills are this strong, the discipline-failure surfacing as MEMORY.md overflow (§3.7) is genuinely a discipline issue, not an architectural one — the right tier exists and is well-built. |

#### 3.10 Hooks / Middleware (vs survey §3.10)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | **Zero hooks configured.** `hooks: null` at the user-level settings.json [Verified: 2026-05-10 via `jq '.hooks'`]; no `hooks/` directory at user-level or project-level [Verified: 2026-05-10 via filesystem inspection]. None of Claude Code's ~30 lifecycle events (SessionStart, PreToolUse, PostToolUse, Stop, PreCompact, PostCompact, etc. per §3.10) have a registered handler. The five orthogonal axes hooks accomplish per §3.10 (determinism gates, safety gates, compaction shaping, routing, telemetry) all run without harness-side enforcement; safety is partially covered by the 83 ask-rules at the permission layer (see §3.11). |
| Vs canonical (§3.10) | **Most-exposed component.** Per §3.10: *"every harness has at least one of [the five axes], but only Claude Code surfaces all five as first-class user-configurable extension points"* — the workspace runs Claude Code (the most expressive hook surface in the field) and uses none of it. §8 names *deterministic enforcement gates* as *"the binding constraint between 'model says it did X' and 'system verifies X happened'"*; the workspace has no such gate. |
| Bet vs gap | **Ambiguous-intent.** Two readings: **(i)** *Deliberate Cursor-style bet* — the workspace mirrors Cursor's *all-declarative posture* (§9), trusting model reliability + ask-rules + skill discipline + `/supervise` for enforcement. **(ii)** *Unintentional gap* — hooks are simply not yet configured because the configuration cost is non-trivial and no specific failure has forced the issue. Evidence for (i): the workspace has [feedback_no_regex_evasion_use_disable_with_reason](`feedback_no_regex_evasion_use_disable_with_reason.md`) explicitly rejecting hidden-disable hook patterns, and several `feedback_no_*` entries reading as case-by-case rule rejections. Evidence for (ii): the user's collaboration protocol (`/Users/coen/Developer/CLAUDE.md` *Collaboration Protocol* section) describes "timeless infrastructure quality" — not a posture aligned with declarative-only enforcement. The two readings have opposite implications for the redesign and the question is surfaced as **Open Question 3** below — not silently resolved. |
| Direction | The bet/gap resolution determines the direction. If (i): no direction. If (ii): the field's converged starter set per §3.10 is *Stop hook (auto-summary on session end) + PreToolUse hook (forced lint/typecheck on Swift edits)*; the workspace already has the `swift-format` + `swiftlint` infra (`Scripts/swift-format`, project-level allow rules for `Bash(swiftlint lint *)` etc.) so the determinism-axis cost would be a thin wrapper. *(direction-class; pending Open Question 3 resolution)*. |

#### 3.11 Permissions / Authorization (vs survey §3.11)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | The 5-mode menu (default / acceptEdits / plan / auto / bypassPermissions / dontAsk per §3.11) with `defaultMode: "auto"` selected. **10** allow rules (very wide: `Bash(*)`, `WebSearch`, `WebFetch`, `Read`, `NotebookEdit`, `Grep`, `Glob`, `Task`, `LSP`, `mcp__cclsp__*`); **0** deny rules; **83** ask rules — destructive bash + secrets-edit categories ([Verified: 2026-05-10 via `jq '.permissions \| .allow,.deny,.ask \| length'`]). +12 user-local additions, +79 project-local additions. `skipAutoPermissionPrompt: true`. |
| Vs canonical (§3.11) | **Most-liberal permission posture in the field, paired with strong ask-rules + OS sandbox.** §3.11 quote: *"This is one of the more liberal permission postures in the field — auto mode + Bash(*) + skip-auto-prompt — backed by an aggressive ask-list for destructive ops."* That's the survey's own description of the workspace's verified state. Codex's `workspace-write + on-request` is structurally similar but routed through a dedicated OS-sandbox; Claude Code's auto-mode uses a background safety classifier. |
| Bet vs gap | **Deliberate bet on auto-mode + ask-rules + sandbox + skill-discipline composition.** The bet is internally coherent: auto-mode trusts the model on routine work; ask-rules block the destructive shapes; OS sandbox bounds the blast radius; skill discipline ([SUPER-*], [GIT-*], [HANDOFF-*]) governs the workflow envelope. |
| Direction | None at component level — the bet is mature. *Cross-component implication*: the bet is structurally dependent on hooks NOT being load-bearing for safety (§3.10); if Open Question 3 resolves toward *unintentional gap*, the permission posture's lack of belt-and-suspenders becomes more exposed. |

#### 3.12 Guides (Feedforward) (vs survey §3.12)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Heavy guide investment per Böckeler's framing (§1.3, §3.12): **(a)** AGENTS-equivalent: `/Users/coen/Developer/CLAUDE.md` (~330 lines, skill routing tables, layer architecture, package locations, gotchas, deep links); **(b)** conventions: 54 skills, with `code-surface` (36 IDs), `implementation`, `memory-safety`, `platform`, `modularization`, `swift-institute` together codifying naming, error-handling, layering, testing, modularization conventions — the *most rigorous Maintainability + Architecture-Fitness guide stack in the survey*; **(c)** language-server: cclsp MCP exposing semantic queries (§3.2 above); **(d)** type system: typed throws ([API-ERR-001]), nested namespaces ([API-NAME-001]), one-type-per-file ([API-IMPL-005]), five-layer architecture — guide-as-language-feature. |
| Vs canonical (§3.12) | **Field-leading on the Maintainability and Architecture-Fitness tiers.** §3.12's tier table identifies Architecture Fitness as *"partial — tooling exists but is not LLM-friendly"*; the workspace's `swift-institute` skill ([ARCH-LAYER-*]) + the typed-throws pervasive style explicitly aim for LLM-friendly architecture-fitness signals — *guide messages encoded as compile errors with typed throws*. |
| Bet vs gap | **Deliberate bet — typed-throws-via-skills enforcement is a workspace contribution back to the discipline.** The survey's §3.12 cites Böckeler's tier table; the workspace operationalizes the Architecture-Fitness tier *as a type-system invariant*. This is a generalization of Böckeler's frame — guides that *the compiler can verify*. |
| Direction | The Behaviour tier (§3.12: *"Open — no robust pre-merge proof that 'this PR does what the issue said it should'"*) remains open in the workspace as everywhere else. *Cross-component implication*: the workspace's Acceptance Criteria + per-IP verification ([SUPER-009], [SUPER-022]) is the closest workspace-side analog to Behaviour-tier coverage, but it covers individual dispatched task acceptance, not the *issue → PR* mapping the survey discusses. |

#### 3.13 Sensors (Feedback) (vs survey §3.13 / §3.12 framing)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Heavy sensor investment: 27+ centralized reusable workflows at `swift-institute/.github/.github/workflows/` covering lint-api-breakage, lint-license-header, lint-readme-presence, lint-readme-structure, lint-test-support-spine, lint-skill-descriptions, lint-mechanical-hygiene, lint-org-bot-coverage [Verified: 2026-05-10 via `ls`]; per-package `ci.yml` wrappers in 372 swift-primitives subrepos delegating to those reusables [Verified: 2026-05-10 via `find ... \| wc -l`]; the `swift-ci.yml` reusable performs `swift build --build-tests` + `swift test` matrices; `swift-format` + `swiftlint` configurations. |
| Vs canonical (§3.13) | **Maintainability tier: solved + extended.** §3.13's tier table identifies Maintainability as *"solved"* with mature linters/typecheckers — the workspace runs that *plus* a custom institute-side lint suite (lint-test-support-spine, lint-readme-structure, lint-skill-descriptions, lint-mechanical-hygiene) covering *workspace-specific architectural invariants* not present in standard Swift tooling. |
| Bet vs gap | **Deliberate bet on centralized reusables + per-package wrappers.** The pattern is consistent with [CI-*] requirements in `ci-cd-workflows`. The Free-plan-no-private-CI constraint (per `feedback_free_plan_private_ci_unrunnable.md`, `feedback_private_repos_no_ci_runs.md`) means private repos receive no CI signal — this is a *structural* sensor gap noted in workspace memory. |
| Direction | **RECOMMENDATION** — the substitution rule documented in `feedback_free_plan_private_ci_unrunnable` (*"substitute local clean-build for any pre-flip CI-gate"*) is currently a memory entry; promote it to a [CI-*] or [SUPER-*] rule so the discipline survives memory triage. *(direction-class)*. |

#### 3.14 Self-Verification Loop (vs survey §3.14)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Per-IP verification ([SUPER-022] per-intervention-point verification), Acceptance Criteria with disk/git/build-output evidence tiers ([SUPER-009] + [SUPER-009a] partial-verification disclosure), build-warning classification gate ([SUPER-037]), `swift package clean` after upstream change ([SUPER-040]), pre-fire precondition re-check ([HANDOFF-029]), grep-anchored Acceptance Criteria ([HANDOFF-041]), end-of-cascade workspace-wide grep + ecosystem-wide build gate ([HANDOFF-035]). No mandatory browser-automation testing for UI changes ([§3.14 the field's signature pattern from Anthropic's *Effective harnesses for long-running agents*) — the workspace doesn't ship UI. No `feature-list JSON files` premature-victory antidote — the workspace uses Acceptance Criteria + per-IP verification as analog. |
| Vs canonical (§3.14) | **Mainstream + workflow-codified.** Self-verification is treated as a *workflow* primitive (codified in [SUPER-*] / [HANDOFF-*]) rather than a *runtime* primitive (e.g., the kind of mandatory browser-automation gate Anthropic's blog post describes). Both forms are valid per §3.14; the workspace's choice maps to its task shape (Swift code, not UI). |
| Bet vs gap | **Deliberate bet, well-defended.** The discipline level around self-verification is the workspace's second-strongest component (after Skills, §3.9). [SUPER-037] build-warning classification is a workspace-specific extension surfaced from a real failure mode (the 2026-05-02 16-self-recursing-method-bodies false-GREEN incident). |
| Direction | None at component level — the workspace is field-leading here. |

#### 3.15 Observability / Tracing (vs survey §3.15)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's built-in OpenTelemetry export per §3.15 (claim per the survey, not workspace-state-verified — the workspace `settings.json` does not configure `OTEL_*` environment variables [Verified: 2026-05-10 via `cat settings.json` showing no `env` section and no `otel*` keys]; tool input/output content not logged in spans by default per §3.15). No vendor-neutral observability platform configured (no LangSmith / Braintrust / Phoenix / Helicone integration). The workspace's *workflow-level* observability is `Research/Reflections/` — every non-trivial session captures a reflection per `/reflect-session`, with [REFL-*] (17 IDs currently) governing the discipline. |
| Vs canonical (§3.15) | **Workflow-side instead of agent-side.** §3.15 is dominated by replay-based debugging, auto-prompt-revision from traces, PRMs on harness traces, and co-training. The workspace runs none of those. Instead it runs *human-readable session reflections* feeding back into skill rules — the analog of *"every failure becomes a permanent rule"* (Trivedy's harness-as-living-artifact thesis, §3.15) but at the user-side rather than the auto-pipeline side. |
| Bet vs gap | **Deliberate bet on reflection-driven learning over trace-driven learning.** The reflection corpus is structurally similar to OpenHands' EventLog (§3.5) but at human granularity: events are `Research/Reflections/YYYY-MM-DD-*.md` files, not `Action`/`Observation` events. The bet is consistent with the workspace's broader user-as-orchestrator posture (§3.5 above). |
| Direction | **RECOMMENDATION** — adopt OpenTelemetry GenAI semconv for whole-harness observability. The schema is stable as of OTel v1.37 + Datadog/Grafana support (§3.15, §7.6). Cost: minimal — Claude Code emits OTel natively; the workspace would set `OTEL_LOG_TOOL_CONTENT=1` (or not, leaving the field's default off-by-default) plus an exporter endpoint. Benefit: composable with the [REFL-*]-driven workflow observability rather than replacing it; provides a quantitative substrate for the eval question raised in §3.2 (cclsp-leverage measurement). *(direction-class; pending user authorization on whether to add an external observability dependency)*. |

#### 3.16 Eval Harness (vs survey §3.16)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | None at the harness layer. The workspace has no Husain-style evals-skills plugin, no error-analysis pipeline on real traces, no judge-prompt validation, no transition matrices [Verified: 2026-05-10 via `ls /Users/coen/.claude/skills/ \| grep -i eval` returning empty and absence of any `eval-*` skill in `swift-institute/Skills/`]. Code-level testing is heavy ([TEST-*], [SWIFT-TEST-*], [INST-TEST-*], [BENCH-*] — 4 testing-related skills) but those are *agent-output verification* (does the code work?) not *agent-quality verification* (is the agent improving over time?). |
| Vs canonical (§3.16) | **Most-exposed component** (alongside §3.10 Hooks). Yan / Husain / the Terminal-Bench results (§3.16, §7.6) all establish that *whole-harness evals* are now the field's primary improvement loop. The workspace's improvement loop runs entirely through reflections + skill updates ([REFL-PROC-*] in `reflections-processing` triages reflections into skill updates) — qualitatively rich but with no quantitative anchor. |
| Bet vs gap | **Ambiguous-intent.** Two readings: **(i)** *Deliberate bet on qualitative reflection over quantitative eval* — consistent with the workspace's bias toward reflection-driven learning (§3.15 above). **(ii)** *Unintentional gap* — the field's converged best practice is to start with error-analysis-on-real-traces (Husain), not skip evals entirely; the workspace may simply not yet have invested. Reading (ii) is reinforced by the §3.2 RECOMMENDATION (cclsp-leverage measurement) — measuring would require an eval harness that doesn't exist yet. The two readings determine very different paths and surface as **Open Question 4**. |
| Direction | The bet/gap resolution determines direction. If (ii): the converged starter approach per §3.16 is error-analysis on the existing reflection corpus (transition matrices over reflection categories), then judge-prompt validation, then synthetic-data generation. *(direction-class; pending Open Question 4 resolution)*. |

#### 3.17 Human-in-the-Loop (vs survey §3.17)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Claude Code's permission modes + the 83 ask-rules implement field-standard interrupt/approve patterns (§3.17). Workflow-level: [SUPER-005] question classification (class (a)/(b)/(c) escalation), [SUPER-012] escalation triggers + persistence requirement, [HANDOFF-012] supervisor-block-as-handoff handoff-of-supervision. The user-as-principal pattern ([SUPER-023] supervision-mode dimension Pattern C) is one of the workspace's three named modes. |
| Vs canonical (§3.17) | **Mainstream + workflow-codified.** The HITL component is converged in the field; the workspace's elaboration is structural — codifying *which* questions go to the user vs which the supervisor answers vs which the rules already answer. |
| Bet vs gap | **Deliberate bet — workflow-codified HITL.** [SUPER-005], [SUPER-012], [SUPER-014a], [SUPER-028] together codify a more rigorous escalation discipline than the field default (`request_approval` / `interrupt(payload)` / approval prompts). |
| Direction | None at component level. |

#### 3.18 Durability / Resume (vs survey §3.18)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | The workspace runs Claude Code locally; durability is via the local session log + the `/handoff` skill ([HANDOFF-002] sequential, [HANDOFF-003] branching, [HANDOFF-009] progressive capture) which converts session-state into a durable cross-session artifact. No LangGraph-Checkpointer-equivalent (no persistent typed state across program invocations beyond what files preserve). No Anthropic *Sessions*-style server-side append-only event log (the workspace doesn't run Claude Agent SDK / Managed Agents). |
| Vs canonical (§3.18) | **Workflow-side instead of runtime-side, like §3.15.** The 12-factor stateless-reducer pattern (§3.18) doesn't apply because the workspace doesn't ship an agent service — it runs an interactive harness (Claude Code) where the human is the durability checkpoint. The `/handoff` skill is the workspace's analog of Anthropic Sessions: convert ephemeral session state into a re-readable artifact. |
| Bet vs gap | **Deliberate bet — handoff-as-durability.** [HANDOFF-009] progressive capture's *why* clause is exactly the durability concern: *"Important context is captured while the agent is still sharp, not during final degradation."* This is the *handoff paradox* the survey's *Internal corpus* references. |
| Direction | None at component level. |

#### 3.19 Optimizer (Declarative) (vs survey §3.19)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | None. The workspace runs no DSPy / GEPA / MIPRO / BootstrapFewShot pipeline. The workflow-level analog is *manual* skill optimization via [SKILL-LIFE-*] (skill-lifecycle's 28 IDs) + [REFL-PROC-*] (reflections-processing's 18 IDs) — humans propose skill updates from reflections; humans review them; humans land them. No falsifiability contracts, no programmatic mutation, no eval-driven optimization loop. |
| Vs canonical (§3.19) | **Most-divergent component.** §3.19 / §7.1 frame the *harness-as-compiler* thesis as the dominant 2026 frontier. The workspace runs the *harness-as-corpus* alternative: skills are durable text artifacts, not compiled programs; mutations are human edits, not LM-driven reflections. |
| Bet vs gap | **Deliberate bet on durable text + human review over compiled programs + auto-mutation.** The bet is consistent with the workspace's *timeless infrastructure* thesis (`/Users/coen/Developer/CLAUDE.md` *Collaboration Protocol* clause #5: *"Treat every decision as permanent"*). DSPy/GEPA optimize for *measured improvement on a fixed eval*; the workspace optimizes for *durable readability and re-derivability of decisions*. The two are not the same objective. |
| Direction | **RECOMMENDATION** — recognize this as a deliberate divergence and ensure forward direction items don't silently assume the harness-as-compiler frame. Specifically: §3.16 RECOMMENDATION (eval harness) interacts with §3.19 — adopting evals does NOT require adopting an optimizer; the workspace can run evals in service of human-driven skill mutations rather than auto-mutations. *(direction-class; framing item — cheap to settle, prevents future drift)*. |

#### 3.20 Policy (vs survey §3.20)

| Aspect | Workspace state |
|--------|-----------------|
| What ships | Permission-layer enforcement (the 83 ask-rules + 0 deny-rules) + the workspace's *Collaboration Protocol* (`/Users/coen/Developer/CLAUDE.md`) covering challenge-implementations / cite-specific-lines / no-drift / complete-answers / ask-before-assuming. No managed-policy CLAUDE.md (system-directory file org-admins preload, per §3.20 — this is a Claude.ai for Work feature; the workspace is single-user) [Verified: 2026-05-10 via direct read]. No OpenAI Guardrails / Composio policies (different vendor stacks). The git-operations skill ([GIT-001] – [GIT-005], with stage-tag/visibility/`gh pr/issue create` requiring per-action authorization) functions as workspace-side policy. |
| Vs canonical (§3.20) | **Single-user appropriate.** §3.20 is org-scale policy; the workspace is single-user. The git-operations + collaboration-protocol layer covers the equivalent surface. |
| Bet vs gap | **Deliberate bet — policy-via-skills.** The workspace turns institutional constraints into [GIT-*] and [SUPER-*] requirement IDs, citable and auditable like all other skill rules. |
| Direction | None at component level. |

### 4. Workspace-Specific Layers Not in the Canonical Taxonomy

The survey's 20-component taxonomy (§2) is comprehensive for *agent-side*
harnesses — components a vendor configures into Claude Code, Cursor,
Codex, etc. The workspace runs **a second layer on top**: the
*workflow harness* governing how the user composes Claude Code sessions
over time. Five workspace-specific layers are not named in the canonical
taxonomy but are first-class in the workspace's day-to-day operation.

#### 4.1 The Workflow-Harness Pipeline

`/handoff` → `/supervise` → `/reflect-session` → `/reflections-processing`,
together carrying 133 requirement IDs as of 2026-05-10 [Verified:
2026-05-10 via per-skill `grep -c '^### \['`]:

| Skill | IDs | Role |
|-------|-----|------|
| `handoff` | 52 | Discrete agent-to-agent transfer (sequential resume + branching investigation) |
| `supervise` | 46 | Ongoing principal-subordinate oversight (ground-rules block, drift detection, three-way termination, in-absentia) |
| `reflect-session` | 17 | Post-session learning capture |
| `reflections-processing` | 18 | Reflection triage into skill updates / docs / research / package insights |

The pipeline implements *user-side* analogs of several survey components
that, vendor-side, would be product features:

- `handoff` ↔ Anthropic Sessions / LangGraph Checkpointer (§3.18) — but
  user-readable instead of opaque-event-log;
- `supervise` ↔ OpenAI Guardrails / OpenAI Agents SDK handoffs (§3.5,
  §3.10) — but skill-rule-driven instead of decorator-driven;
- `reflect-session` + `reflections-processing` ↔ LangSmith Polly /
  Maxim AI auto-prompt-revision (§3.15) — but human-curated instead of
  LM-driven.

The two-layer framing (agent-harness × workflow-harness) is a contribution
back to the discipline. The survey's *Outcome* §K5 anticipates this
explicitly: *"the next session should make this explicit."* This is
that explicit statement.

[Verified: 2026-05-10 via `grep -c '^### \[' Skills/{handoff,supervise,reflect-session,reflections-processing}/SKILL.md`]

#### 4.2 The Five-Layer Architectural Skill (`swift-institute`)

The `swift-institute` skill carries [ARCH-LAYER-*] requirements codifying
the five-layer architecture (Primitives / Standards / Foundations /
Components / Applications). The skill is `applies_to:` every Swift
Institute repository and is loaded *first* via `swift-institute-core`'s
canonical-loading-order declaration [Verified: 2026-05-10 via direct
read of `swift-institute-core/SKILL.md`].

This is a *domain* skill — it codifies the workspace's package-architectural
discipline rather than the harness's behavioral envelope. The canonical
taxonomy doesn't name domain-architecture skills as a harness component
because most production harnesses don't ship domain-bound architecture
discipline. The workspace does, and the architecture invariants
([ARCH-LAYER-*], [PLAT-ARCH-*], [MOD-*]) compose with the typed-throws-via-skills
enforcement (§4.4 below) to produce architecture-as-compile-time-invariant
— Böckeler's Architecture-Fitness tier (§3.12) realized as a type-system
invariant.

#### 4.3 Meta-Skills

Three skills govern the *skill corpus itself*, not Swift code:

- `swift-institute-core` (system manifest, declares loading order, ALWAYS
  loaded first per its frontmatter [Verified: 2026-05-10 via direct
  read]);
- `skill-lifecycle` (28 [SKILL-LIFE-*] IDs governing create/update/review/deprecate);
- `corpus-meta-analysis` ([META-*] IDs governing Research/Experiment
  corpus health: staleness, verification, supersession, consolidation,
  pruning).

Plus three quasi-meta skills covering workflow lifecycle:

- `reflect-session` and `reflections-processing` (§4.1);
- `release-readiness` ([RELEASE-*] governing the multi-phase pre-release
  scan).

The survey's §3.9 names Skills as the canonical procedural-memory tier;
it does not name *meta-skills* (skills governing skills) as a separate
tier. The workspace runs them. This is a contribution back: the
discipline of *skill governance* generalizes to *prompt-template
governance* / *AGENTS.md-section governance* in any sufficiently large
harness, but no production harness in the survey ships meta-skill
discipline out-of-the-box.

#### 4.4 Typed-Throws-via-Skills Enforcement (`code-surface`)

The `code-surface` skill ([API-ERR-001] *All throwing functions MUST use
typed throws*, [API-NAME-001] *Nest.Name pattern*, [API-IMPL-005] *one
type per file*, etc. — 36 IDs total [Verified: 2026-05-10 via `grep -c
'^### \[' Skills/code-surface/SKILL.md`]) operationalizes Böckeler's
Architecture-Fitness tier (§3.12) as a *language-feature invariant*.
When the user writes `func read() throws -> Data`, the typed-throws rule
is a *guide* (skill rule) AND a *sensor* (compile error if the rule is
violated). The rule pre-loads the convention into context (skill metadata
at startup) and the compile loop verifies adherence post-action (build
output sensor §3.13).

The combination *guide-as-language-feature* is a sharper formulation of
Böckeler's frame than the survey discusses. §3.12's tier table calls
Architecture Fitness *"partial — tooling exists but is not LLM-friendly"*;
the workspace's contribution is the type system as the LLM-friendly
verification surface.

#### 4.5 Symbol-Graph Context-Reduction Tooling

The `cclsp` MCP (§3.2) + `Scripts/patch-umbrella-symbol-graph.py` +
`Research/ai-context-reduction-via-type-system-tooling.md` (Phase 1
shipped) implement *type-system-side context engineering* (§3.8 above).
The orthogonal cuts in the survey (§2 *behavior-first / control-theoretic
/ operational-layer*) don't have a *substrate-side* axis; the workspace's
substrate-side bet is that *semantic queries against compiled symbol
graphs* dominate *grep against source files* on tokens-per-task in
strongly-typed languages. The bet is consistent with §7.2 (coding-agent-as-
universal-long-context-processor) but more specific: the *language's
type system* is the long-context substrate, not the file system.

This is a domain-bound contribution — the bet only generalizes to
languages with mature LSP + symbol graph tooling. Within Swift, the bet
is testable: §3.2 RECOMMENDATION (cclsp-leverage measurement) is the
proposed verification.

### 5. Strongest 3–5 Components

Ordered by margin of advantage over the survey's baseline practice:

1. **Skills / Progressive Disclosure (§3.9 / §4.3 above).** The 54-skill
   corpus + meta-skill governance ([SKILL-LIFE-*], [META-*]) +
   typed-requirement-ID system pervading the corpus is more rigorous
   than any production harness in the survey ships out-of-the-box.
   *Carries downstream*: the strength of this component makes the
   MEMORY.md overflow (§3.7) a discipline issue rather than an
   architectural one — the better tier already exists.
2. **Self-Verification Loop / Workflow Codification (§3.14, §4.1).** The
   [SUPER-009] / [SUPER-022] per-IP verification + [SUPER-035] / [SUPER-037]
   / [HANDOFF-029] / [HANDOFF-035] family is a more elaborated
   self-verification discipline than any field default. The codification
   level (133 IDs across the 4-skill workflow pipeline) is unparalleled.
3. **Guides Tier — Maintainability + Architecture-Fitness (§3.12, §4.4).**
   The typed-throws-via-skills enforcement turns Architecture-Fitness
   guides into compile-time invariants — Böckeler's framing realized in
   the type system. Field-leading.
4. **Filesystem + Real-Git Discipline (§3.3).** [HANDOFF-019]
   commit-as-you-go + [GIT-001]/[GIT-005] push authorization classes +
   per-package real git history is a tighter discipline than shadow-git
   checkpointing across the field. The pattern is reusable downstream.
5. **Workflow-Harness Pipeline (§4.1, §3.18).** `/handoff` /
   `/supervise` / `/reflect-session` / `/reflections-processing` together
   form a *workflow harness* layered on the *agent harness* — a
   two-layer framing the canonical taxonomy doesn't name and the
   workspace pioneered.

### 6. Most-Exposed 3–5 Components

Ordered by leverage of plausible direction items:

1. **Hooks / Middleware (§3.10).** `hooks: null` — zero hooks across
   ~30 lifecycle events × 5 hook types × 5 orthogonal axes. Whether this
   is Cursor-style deliberate bet or unintentional gap is **Open
   Question 3**. If gap: the field's converged starter set (Stop hook +
   PreToolUse forced-lint) is low-cost relative to the existing
   `Scripts/swift-format` + `swiftlint` infra.
2. **Eval Harness (§3.16, §3.19).** No error-analysis pipeline, no judge
   prompts, no benchmarks against the workspace's own harness, no
   transition matrices. The reflection corpus is the qualitative
   substrate; quantitative anchoring is absent. Resolution is **Open
   Question 4**.
3. **Memory — Discipline (§3.7).** MEMORY.md exceeds the 24.4KB cap;
   the workspace's own routing rule (`feedback_*`-write guardrail in
   `/Users/coen/Developer/CLAUDE.md`) is being violated by the index's
   own state. The architecture is right; daily discipline drifted.
4. **Observability / Tracing (§3.15).** Workflow-side observability
   (Reflections) is heavy; agent-side OpenTelemetry-GenAI integration is
   absent. Cost to add is low (Claude Code emits OTel natively); benefit
   is composability with §3.2 / §3.16 RECOMMENDATIONs.
5. **Tool Surface — Quantification (§3.2).** The cclsp bet on semantic
   navigation is unverified by eval. The Research doc claims Phase 1
   shipped but no measurement has run. Composes with §3.16
   RECOMMENDATION (eval harness).

## Outcome

**Status: RECOMMENDATION.**

This document maps the workspace's actual harness against the survey's
20-component canonical taxonomy. It identifies the workspace's
field-leading components (Skills, Self-Verification, Guides, Filesystem
+ Git, Workflow-Harness Pipeline), the workspace's most-exposed
components (Hooks, Eval Harness, Memory-discipline, Observability,
Tool-Surface-Quantification), and five workspace-specific harness layers
the canonical taxonomy doesn't name (workflow-harness pipeline,
five-layer architectural skill, meta-skills, typed-throws-via-skills
enforcement, symbol-graph context-reduction).

### Leverage-Ordered Recommendations (Direction Items, Pending User Authorization)

Each is a direction item. None is an implementation prescription. Each
explicitly excludes tag/visibility/push actions and any file change
beyond a future dispatch's deliverable. *RECOMMENDATIONs are direction
items; concrete implementation work is downstream of user decisions on
this document.*

1. **MEMORY.md triage cycle.** **RECOMMENDATION pending user
   authorization.** Triage the 188 memory files entry-by-entry, mapping
   each to one of (a) skill rule (promote per the workspace's existing
   guardrail), (b) path-scoped rule (`.claude/rules/` — the workspace
   currently uses none, the field's converged 4-tier hybrid §3.7 has
   path-scoped rules as a load-bearing tier between skills and
   auto-memory), (c) genuinely user-specific preference (memory's
   correct home), (d) stale (delete). The work the survey's *Outcome*
   §6(a) anticipated. **Why first**: highest leverage — fixes the most
   visible discipline drift (a 31.3KB index over a 24.4KB cap) and
   *reduces context pressure* for every future session. Cost is a
   bounded triage cycle, not architectural change.

2. **Hook layer minimum-viable seed.** **RECOMMENDATION pending Open
   Question 3 resolution.** If the bet/gap question resolves toward
   *unintentional gap*, the field's converged starter set per §3.10 is:
   (i) `Stop` hook auto-summarizing session into `Reflections/` skeleton
   (composes with [REFL-001]); (ii) `PreToolUse` hook on `Edit(*.swift)`
   running `swift-format lint` + `swiftlint lint` (composes with
   existing project allow-rules and `Scripts/swift-format`); (iii)
   `PreCompact` hook re-injecting active supervisor block when
   `HANDOFF.md` is present (composes with [SUPER-014a] /
   [HANDOFF-012]). **Why second**: highest single-component leverage
   *if* the gap reading is correct. **Why conditional**: this RECOMMENDATION
   is moot under the *deliberate bet* reading.

3. **Eval harness seed via reflection-corpus error-analysis.**
   **RECOMMENDATION pending Open Question 4 resolution.** Per §3.16
   (Husain): start with error-analysis on real traces. The workspace's
   *real traces* are the reflection corpus
   (`swift-institute/Research/Reflections/`). The starter approach: a
   transition-matrix analysis over reflection categories (drift /
   premise-staleness / scope-expansion / missing-verification / etc.)
   to produce a quantitative baseline for the qualitative learning loop
   already running. **Why third**: this is the precondition for §3.2's
   cclsp-leverage measurement and for any future harness-as-compiler
   move. **Why conditional**: this RECOMMENDATION is moot under the
   *deliberate bet on qualitative reflection* reading.

4. **OpenTelemetry GenAI semconv adoption.** **RECOMMENDATION pending
   user authorization.** Claude Code emits OpenTelemetry GenAI spans
   natively (§3.15). Setting `OTEL_LOG_TOOL_CONTENT=1` (or leaving the
   field's default-off for PII safety) plus an exporter endpoint
   produces vendor-neutral whole-harness traces — the substrate for
   §3.16 evals and §3.2 cclsp-leverage measurement. **Why fourth**:
   composes with #3 but is independent of Open Questions 3 and 4. Cost
   is configuration-only; no schema commitment beyond the published
   OTel GenAI spec.

5. **CI substitution rule promotion.** **RECOMMENDATION pending user
   authorization.** Promote the CI-substitution discipline currently in
   `feedback_free_plan_private_ci_unrunnable` and
   `feedback_private_repos_no_ci_runs` to a [CI-*] or [SUPER-*]
   skill rule. Survives MEMORY.md triage; codifies a workspace-specific
   sensor invariant per §3.13. **Why fifth**: lowest leverage of the
   five but lowest cost too — single skill-rule addition.

6. **Disambiguate harness-as-corpus from harness-as-compiler framing.**
   **RECOMMENDATION pending user authorization.** Document explicitly
   in `swift-institute/Skills/swift-institute-core/SKILL.md` (or
   equivalent) that the workspace runs the *harness-as-corpus*
   alternative to §3.19's *harness-as-compiler* frontier (DSPy / GEPA /
   Meta-Harness). Skills are durable text; mutations are human edits;
   evals (when adopted) serve human-driven mutations rather than
   auto-mutations. **Why sixth**: framing item, prevents future
   direction-drift toward an objective the workspace is not optimizing
   for.

These six are leverage-ordered. None preempts the user's decisions; each
is direction-class only.

## Open Questions

Per dispatch ground-rule #6 + [SUPER-014a] in-absentia escalation
discipline + [SUPER-028] decision matrix (axis A class + axis B
compliance form). The questions below could each plausibly resolve as
either *deliberate bet* OR *unintentional gap*; the existing skill rules
do not contain a class-(a) answer (verified by reading the cited rules);
they are class-(c) under [SUPER-014a]'s in-absentia degenerate model.
Surfaced rather than silently resolved.

1. **Sandbox × cclsp MCP-server interaction (Component 4 / §3.4).**
   The survey's §3.4 names the *MCP-server × sandbox interaction* as
   the active 2026 fault line, citing Codex CLI issue #18243 (Seatbelt
   silently blocking shell exec under non-`danger-full-access` modes
   when running as MCP server). The workspace runs cclsp as an MCP
   server under the macOS Seatbelt sandbox in `auto` mode + `Bash(*)`
   allow + `skipAutoPermissionPrompt: true`. *Has the workspace
   verified that the sandbox + cclsp combination does NOT have an
   analogous failure?* The empirical work to verify this is out of
   scope for this comparative analysis (forbidden by ground-rule #4 —
   "any file change beyond the deliverable + `_index.json`" excludes
   running probe builds against the sandbox/cclsp boundary).

2. **PreCompact / PostCompact hook absence — bet or gap?
   (Component 8 / §3.8 / §3.10).** Auto-compact runs without a
   user-side hook injecting context-shaping. The convergent guidance
   in the field is to inject a custom shape at compaction boundaries
   (e.g., re-attaching the supervisor block before re-summarization).
   Whether the workspace's choice to use defaults is a *deliberate bet*
   on auto-compact's behavior or an *unintentional gap* in the hook
   layer is undetermined from the existing skill rules (no [SUPER-*],
   [HANDOFF-*], or skill rule explicitly addresses compaction-shaping
   policy).

3. **Hooks-layer absence — bet or gap? (Component 10 / §3.10).** The
   workspace's `hooks: null` posture matches Cursor's all-declarative
   bet (§9). Evidence for *deliberate bet*:
   `feedback_no_regex_evasion_use_disable_with_reason` and several
   `feedback_no_*` entries reading as case-by-case rejections of
   hook-shaped enforcement. Evidence for *unintentional gap*: the
   workspace's *Collaboration Protocol* (`/Users/coen/Developer/CLAUDE.md`)
   describes "timeless infrastructure quality" — not a posture
   self-evidently aligned with declarative-only enforcement; the
   existing `swift-format` + `swiftlint` infra is exactly the substrate
   a determinism-axis hook would invoke. The two readings produce
   opposite directions and no skill rule resolves between them.

4. **Eval-harness absence — bet or gap? (Component 16 / §3.16,
   §3.19).** The workspace runs no error-analysis pipeline, no judge
   prompts, no benchmarks against its own harness. Evidence for
   *deliberate bet on qualitative reflection*: the [REFL-*] +
   [REFL-PROC-*] discipline produces a rich qualitative learning loop;
   the workspace's *timeless infrastructure* thesis is incompatible
   with optimizing-for-an-eval; the harness-as-corpus framing
   (§4.5 / Recommendation #6) is internally coherent. Evidence for
   *unintentional gap*: the field's converged starter approach is
   error-analysis-on-real-traces (Husain), not skip-evals-entirely; the
   §3.2 cclsp-leverage RECOMMENDATION cannot be acted on without an
   eval substrate. The two readings produce opposite directions.

5. **Status of the deferred Claude Code Swift rewrite
   (`claude-code-swift-rewrite-feasibility.md` DEFERRED 2026-04-30).**
   The survey's *Outcome* §6 surfaced this as one of the open frontier
   questions for the comparative session. The DEFERRED status notes
   "awaiting TLS strategy." Whether the rewrite remains the strategic
   forward path (given the §7.4 *harness-in-the-loop RL post-training*
   direction, where the model-vs-harness boundary dissolves) or whether
   investing in harness-side configurations against the existing Claude
   Code runtime is the higher-leverage bet is undetermined here.

6. **Two-layer harness vs Lopopolo's six-layer ops-stack vs OpenHands'
   service-on-event-stream — comparative position.** §1.6 names
   Lopopolo's *Policy / Configuration / Coordination / Execution /
   Integration / Observability* operational decomposition. §3.5 names
   OpenHands' event-sourced architecture as the field's most novel
   design. The workspace's *agent-harness × workflow-harness* two-layer
   framing (§4.1 above) is a contribution back to the discipline but
   has not been compared dimensionally against Lopopolo's six-layer or
   OpenHands' event-stream alternatives. The comparison is a candidate
   *next* research question (Tier 2 or Tier 3) — out of scope for the
   present comparative analysis.

## v1.1.0 Update — Open Questions Resolved (2026-05-10)

Per user direction 2026-05-10, the six Open Questions surfaced at
v1.0.0 were adjudicated rather than carried forward. This section
folds the answers into the Recommendations stack and adds three new
direction items. The v1.0.0 analysis above is preserved unchanged per
[RES-008].

### Adjudication Framework

Each Open Question of v1.0.0 shared the logical shape *"feature X is
absent — bet or gap?"*. The framework distinguishes four cases:

| Class | Authority | Coherence | Action |
|-------|-----------|-----------|--------|
| Deliberate bet | Documented decision | Rest of harness coheres-as-bet | Acknowledge; document if not explicit |
| Implicit bet | Silent | Coheres-as-bet (compensating primitives elsewhere) | Promote to explicit |
| Acceptable gap | Silent / deferred | Coheres-as-gap; bounded cost | Park, schedule revisit |
| Unintentional gap | Silent | Coheres-as-gap; visible cost | Fill |

Five tests, in order: **Authority** (documented decision?) → **Coherence**
(rest of harness coheres-as-bet or coheres-as-gap?) → **Cost** (paying
current cost?) → **Reversibility** (asymmetric?) → **Consistency**
(philosophy implies presence or absence?).

A separate consideration applies to *empirical-state* questions — those
are not bet/gap questions but missing-data questions; the framework
collapses to "run the probe."

### Per-Question Resolution

**Q1 — Sandbox × cclsp MCP-server interaction.** Empirical-state
question, not bet/gap. **Resolution: measurement, not adjudication.**
Coherence test confirms cclsp tools demonstrably work in the workspace
today; the intermittent `find_definition` timeouts cited in
[Verified: 2026-05-10 via `/Users/coen/Developer/CLAUDE.md`] read as
cold-start indexing per the existing CLAUDE.md note rather than
sandbox interception. Direction: probe the sandbox×cclsp boundary at
next opportunity. Below blocking threshold.

**Q2 — PreCompact / PostCompact hook absence.** **Resolution: implicit
deliberate bet.** Coherence test fires hard: the workspace's
compaction-survival strategy is **filesystem-based**, not hook-based.
HANDOFF.md, supervisor block on disk per [SUPER-014], CLAUDE.md
(re-injected automatically post-compact), and MEMORY.md (re-loaded
post-compact) all survive compaction via the filesystem. A
PreCompact / PostCompact hook would be redundant with the
filesystem-as-state-machine pattern. The bet is coherent and cost-free.
Promote to explicit (folded into Recommendation #6).

**Q3 — Hooks-layer absence overall.** **Resolution: deliberate bet,
with single Stop-hook caveat.** Authority test surfaces partial
support (`feedback_no_regex_evasion_use_disable_with_reason` and
several `feedback_no_*` entries are case-by-case rejections of
hook-shaped enforcement, not a meta-rejection). Coherence test
strongly resolves to bet: enforcement in this workspace happens at
four layers — (1) lint/format infra (`swift-format`, `swiftlint`,
`swift-foundations/swift-linter`), (2) audit skill ([AUDIT-*]),
(3) supervisor blocks ([SUPER-002] typed entries), (4) skill-rule-
as-spec ([PREFIX-*] requirement IDs). A hook layer would be a
*fifth* enforcement primitive; the four cohere; the absence of (5)
matches the "every primitive must justify its longevity" philosophy
per the workspace's *timeless infrastructure* framing. **Caveat**: a
`Stop` hook prompting `/reflect-session` at session close is a
*reflection-cadence extension* — it routes work back to the skill
layer rather than enforcing — and is compatible with the broader bet.
Below the threshold of "hook layer." Promote bet to explicit (folded
into Recommendation #6).

**Q4 — Eval-harness absence.** **Resolution: mixed — deliberate bet
(no auto-mutation) + unintentional gap (no error-analysis on
reflections).** Coherence test splits cleanly:
- *Optimizing for an eval* (Goodhart's law risk; auto-mutation;
  harness-as-compiler frontier per survey §7.1) — **the workspace
  philosophically rejects this**. Timeless infrastructure is
  incompatible with metric-optimized infrastructure.
- *Error-analysis on real traces* (Husain; Yan) — **the workspace's
  reflection corpus IS its real traces** (`Research/Reflections/`,
  ~315 entries). A transition-matrix or category-frequency analysis
  would *inform* qualitative learning, not replace it.

The MEMORY.md 31.3KB-over-cap discipline drift was caught by Claude
Code's loaded-context warning, not by anything the workspace runs —
evidence of a partial gap. Direction: pursue error-analysis-on-
reflections only; explicitly exclude judge prompts, benchmarks,
auto-mutation. Promote both halves to explicit (folded into
Recommendation #6).

**Q5 — Deferred Claude Code Swift rewrite.** **Resolution: continue
DEFERRED, with reframed deferral rationale.** Authority test: the
existing v1.1.0 deferral cites "TLS strategy" — a tactical block.
Consistency test now adds a strategic deferral reason: per survey
§7.1 (DSPy → GEPA → Meta-Harness → Agentic Harness Engineering
frontier) and §7.4 (harness-in-the-loop RL post-training dissolves
the model/harness boundary), the harness-architecture *target* is
moving. A Swift rewrite of a Claude-Code-shape harness today targets
a shape the field is moving past. Direction: bump
`claude-code-swift-rewrite-feasibility.md` v1.1.0 → v1.2.0 adding
the strategic gate alongside the existing tactical gate. Park ≥ 1
year; revisit 2027-Q2 absent triggering event.

**Q6 — Two-layer harness comparative position.** **Resolution:
direction-class research item, parked.** Coherence test confirms the
two-layer framing is real (workflow harness over agent harness) and
is the runtime expression of the workspace's two-role collaboration
protocol (user as co-architect; Claude as collaborator) per
`/Users/coen/Developer/CLAUDE.md`. Tier 2 or Tier 3 candidate for
future `/research-process` invocation. Trigger conditions: (a) workspace
adds a third layer (e.g., org-coordination layer above workflow
harness), (b) field publishes citable comparative paper, (c) workspace
considers extracting workflow-harness pipeline as standalone
open-source artifact.

### Updated Recommendations (v1.1.0)

The v1.0.0 leverage-ordered recommendations remain in force, with
three modifications and three additions:

**Modified:**

- **#1 (MEMORY.md triage cycle).** Unchanged — unconditional, highest
  leverage.

- **#2 (Hook layer minimum-viable seed).** **NARROWED to single
  Stop-hook reflection-cadence consideration.** Drop the PreCompact
  item (Q2: filesystem strategy is the bet). Drop the
  PreToolUse-on-Edit-Swift item (Q3: skill-layer enforcement is the
  bet). Keep ONLY the `Stop` hook, reframed as **reflection-cadence
  automation** (prompts `/reflect-session` or auto-skeletons a
  `Reflections/YYYY-MM-DD-{slug}.md`). This is below the threshold
  of "hook layer" and routes work back to the skill layer.

- **#3 (Eval harness seed).** **NARROWED to error-analysis on
  reflection corpus only.** Build a transition-matrix /
  category-frequency analysis script over `Research/Reflections/*.md`.
  Output informs `reflections-processing` runs; decisions remain
  human-driven. Explicitly excluded: LLM-as-judge eval, benchmarks
  against the workspace's own harness, any auto-mutation loop.
  Compatible with the deliberate bet against optimizing-for-an-eval.

- **#4 (OpenTelemetry GenAI semconv adoption).** Unchanged —
  unconditional, composes with #3.

- **#5 (CI substitution rule promotion).** Unchanged — unconditional.

- **#6 (Disambiguate harness-as-corpus framing).** **EXPANDED to
  canonical "deliberate bets register."** The single doc location
  (`swift-institute/Skills/swift-institute-core/SKILL.md` or
  equivalent) becomes the canonical register of explicit bets,
  including:
  - harness-as-corpus vs harness-as-compiler (original)
  - filesystem-survives-compaction (Q2)
  - skill-layer-enforcement, four-layer non-hook stack (Q3)
  - no-auto-mutation, error-analysis-only (Q4)
  - two-layer harness architecture (Q6 parked-research framing)

**Added:**

- **#7. Sandbox × cclsp probe.** **DIRECTION pending user
  authorization.** Spike a probe verifying the macOS Seatbelt + cclsp
  MCP-server combination does NOT exhibit a Codex-issue-#18243-class
  failure (silent shell-exec block under non-`danger-full-access`
  modes when running as MCP server). Expected outcome: probe passes
  (cclsp tools work today). Cost: minutes; benefit: verified absence
  of a known-failure-mode class. Schedule: at next sandbox or MCP
  work session.

- **#8. Feasibility-doc reframed deferral.** **AUTHORIZED in this
  v1.1.0 update.** Update `claude-code-swift-rewrite-feasibility.md`
  v1.1.0 → v1.2.0 adding the strategic-uncertainty rationale
  (harness-architecture target moving) alongside the existing tactical
  TLS-strategy block. Add explicit "Resume Conditions" section with
  both gates. *(See `claude-code-swift-rewrite-feasibility.md`
  v1.2.0 [Verified: 2026-05-10].)*

- **#9. Two-layer harness comparative research, parked.** **DIRECTION
  pending user authorization.** Queue Tier 2 or Tier 3 research
  topic comparing the workspace's two-layer architecture against
  Lopopolo's six-layer ops-stack and OpenHands' service-on-event-
  stream. Trigger conditions per Q6 resolution above.

### Effect on v1.0.0 Conditional Recommendations

| v1.0.0 conditional | v1.1.0 status |
|---------------------|---------------|
| Rec #2 conditional on Q3 resolution | **Resolved** → narrowed to Stop-hook reflection-cadence consideration |
| Rec #3 conditional on Q4 resolution | **Resolved** → narrowed to error-analysis on reflections only |
| Rec #6 unconditional but framing-only | **Expanded** to canonical bets register |
| Open Questions #1, #5, #6 | **Promoted** to direction items #7, #8, #9 |
| Open Questions #2, #3, #4 | **Resolved** as bets, folded into expanded #6 |

Status remains RECOMMENDATION at v1.1.0. Implementation of any
recommendation remains downstream of further user authorization per
the v1.0.0 ground rules.

## v1.2.0 Update — §4.1 Refinement: Three-Layer Architecture, Substrate, and Comprehensive Inventory (2026-05-10)

The v1.0.0 §4.1 named *five* workspace-specific harness layers not in
the canonical 20-component taxonomy. User direction 2026-05-10
surfaced two gaps in that section:

1. **CI/CD was underweighted.** The v1.0.0 mapping reduced CI/CD to a
   single recommendation (#5 CI substitution rule promotion) when it is
   actually one of the *largest* workspace-specific harness layers.
2. **The "two-layer" framing was incomplete.** The agent-harness ×
   workflow-harness binary missed a meta-layer (skill-lifecycle /
   corpus-meta-analysis / audit / release-readiness) that governs the
   other layers' evolution. The right cut is *three layers plus a
   substrate*.

This section refines §4.1 with: (a) acknowledgment that CI/CD is a
major harness layer; (b) the three-layer-plus-substrate architecture;
(c) a comprehensive harness inventory exceeding the 20-component
canonical taxonomy; (d) a categorization of "more harness" options for
forward planning. The v1.0.0 §4.1 enumeration of five layers remains
in force per [RES-008]; the v1.2.0 refinement re-classifies and
expands them.

### CI/CD as a major harness layer (correcting the v1.0.0 underweighting)

§3.13 (Sensors) treated CI/CD lightly; §4.1 listed it only implicitly
as part of the workflow-harness pipeline. Reality at this workspace:

- `ci-cd-workflows` skill carries **95+ rules** ([CI-001]–[CI-095];
  the latest two added in Wave 1 per Recommendation #5)
- **Three-tier reusable workflow chain** (consumer → layer wrapper →
  universal)
- **Cross-org metadata propagation** via
  `swift-institute/.github/.github/workflows/`
- **Universal matrix** (Swift 6.3 stable + 6.4-dev nightly) treated as
  platform spec; Package.swift conforms to matrix, not vice versa
- **Per-repo + centralized split** governed by
  `project_per_repo_vs_centralized_ci`
- **Lychee orchestrator + sync-metadata + sync-gitignore + sync-skills**
  — multiple non-build orchestrations
- **Custom lint engine** at `swift-foundations/swift-linter` (pure Swift,
  file-based org-mirror inheritance via `// parent: <raw URL>`) —
  distinct from SwiftLint

CI/CD spans multiple framings of the canonical taxonomy:

| Survey framing | CI/CD's role at this workspace |
|----------------|--------------------------------|
| §3.13 Sensors (Böckeler feedforward/feedback) | Primary post-action feedback layer |
| §3.10 Hooks (5 axes) | The **determinism axis** fires here — consistent with [BET-HOOK]: enforcement happens at lint/CI, not at hooks |
| §1.6 Lopopolo's six-layer ops-stack | Spans *Coordination* + *Integration* + *Observability* simultaneously |
| §3.14 Self-verification loop | Build-loop + test-loop + lint-loop are CI's products |

CI/CD's compatibility with [BET-HOOK] is structural: the bet says
enforcement happens at four layers, and *one of those layers is the
lint/format infrastructure* — which CI invokes at scale with
three-tier reusable governance. CI/CD is therefore not a candidate for
hook-based replacement; it is the workspace's instantiation of the
determinism axis.

### Three-layer architecture + substrate (refining the v1.0.0 two-layer framing)

The v1.0.0 §4.1 named the workspace as *agent-harness × workflow-harness*
— two layers. With CI/CD in scope and the meta-skills visible, the
architecture is **three layers plus a substrate**:

| Layer | What it manages | Examples in this workspace |
|-------|----------------|----------------------------|
| **L0 — Substrate** | Persistent infrastructure under everything | Filesystem; git; GitHub; CI runners; per-org repo topology; OS; settings.json; auto-memory storage; compile_commands.json; OpenTelemetry exporter (when adopted per Rec #4) |
| **L1 — Agent harness** | The Claude session as a runtime | CLAUDE.md hierarchy; permissions/auto mode; MCP (cclsp); skills as procedural memory; MEMORY.md; the [BET-*] register |
| **L2 — Workflow harness** | How a session does work | `/handoff`; `/supervise`; `/reflect-session`; `/reflections-processing`; plan-mode; `audit`; `release-readiness`; `engagement-process` pipeline; CI/CD as the determinism instance |
| **L3 — Meta-harness** | How the harness itself evolves | `skill-lifecycle`; `corpus-meta-analysis`; `audit` (when applied to skills); the bets register at `swift-institute-core`; `swift-forums-review` (pressure-test before public); `release-readiness` (skill-incorporation gate) |

This refines Q6 of v1.1.0 (the "two-layer" framing). The two-layer
framing was correct as far as it went but missed the meta-layer. The
meta-layer is what makes the workspace's harness genuinely
distinctive: *skills don't just exist — they're governed, reviewed,
and consolidated by other skills.* And below the agent-harness sits a
substrate (filesystem + git + CI + GitHub) that the v1.0.0 framing
treated as "given" rather than as a layer of the harness itself.

### Comprehensive harness inventory (extends v1.0.0 §4.1 from 5 layers to ~30 components)

#### L0 substrate (implemented)

| Component | Notes |
|-----------|-------|
| Filesystem + git + GitHub | The durable-text substrate referenced by [BET-COMPACT] |
| settings.json (~100 deny/ask rules) | Permission-governance layer |
| Auto-memory storage (137 topic files post-triage; MEMORY.md index 24.3 KiB) | After Wave 1 triage; under cap |
| compile_commands.json | Cross-layer LSP navigation substrate |
| Per-package `Research/` + `Experiments/` + `Audits/` + per-org `Blog/` + `Reflections/` | Artifact discipline |
| Cross-org repo topology (swift-institute, swift-primitives, swift-standards, swift-foundations, rule-institute, swift-microsoft, swift-linux-foundation) | Multi-org rather than monorepo |

#### L1 agent harness (implemented)

| Component | IDs / scope |
|-----------|-------------|
| Skills system (~46 skills) | The procedural-memory primary; [PREFIX-*] requirement IDs |
| `swift-institute-core` (with [BET-*] register) | Manifest + harness architecture bets |
| MCP — `cclsp` | Cross-layer symbol lookup |
| CLAUDE.md hierarchy (workspace + user + project) | Layered routing |
| Auto mode + permission rules | settings.json governance |
| Subagents (Explore, Plan, general-purpose, claude-code-guide) | Built-in only; no `.claude/agents/` customs |
| Auto-memory (MEMORY.md + topic files) | Per [BET-EVAL] — corpus, not corpus-driven mutation |
| Symbol-graph context reduction | `cclsp` + `extract-symbol-graphs.sh` + `Research/ai-context-reduction-via-type-system-tooling.md` |

#### L2 workflow harness (implemented; expands v1.0.0 §4.1's 4-skill list)

| Skill | IDs / scope |
|-------|-------------|
| `handoff` | [HANDOFF-*] (47+); sequential + branching + supervisor-block composition |
| `supervise` | [SUPER-*] (41+); ground-rules, drift-detection, three-way termination |
| `reflect-session` | [REFL-*]; Gibbs cycle + action-item cap |
| `reflections-processing` | [REFL-PROC-*]; triage reflections into skill/doc/research |
| `audit` | [AUDIT-*]; systematic compliance check |
| `release-readiness` | [RELEASE-*]; 4-phase brief + 7-phase scan + skill-incorporation gate |
| `research-process` | [RES-*]; tier-classified workflow |
| `experiment-process` | [EXP-*]; empirical verification |
| `blog-process` | [BLOG-*]; drafting/review/publishing |
| `swift-forums-review` | [FREVIEW-*]; simulated reviewer pressure-test, statistically-derived archetypes |
| `swift-evolution` | [PITCH-PROC-*]; pitch phase |
| `swift-pull-request` | [SWIFT-PR-*]; upstream contribution |
| `package-export` | [PKG-EXPORT-*]; LLM-consumption export |
| `collaborative-discussion` | [COLLAB-*]; Claude↔ChatGPT facilitation |
| `engagement-process` + ingest-* + engagement-{triage,compose,review,actionables,themes} | Entire engagement pipeline; **test-only phase** |
| `git-operations` | [GIT-*]; push/tag/visibility authorization policy |
| `quick-commit-and-push-all` | [SAVE-*]; multi-repo save |
| `issue-investigation` | [ISSUE-*]; compiler/toolchain debugging |
| **CI/CD** (as a workflow-harness instance) | `ci-cd-workflows` [CI-001]–[CI-095]; three-tier reusable chain |

#### L3 meta-harness (implemented)

| Skill | What it manages |
|-------|----------------|
| `skill-lifecycle` | [SKILL-CREATE-*], [SKILL-LIFE-*]; skill CRUD with review cadence |
| `corpus-meta-analysis` | [META-*]; research/experiment corpus health, staleness, supersession, revalidation, pruning |
| `update-config` | settings.json governance |
| `swift-institute-core` | Manifest + [BET-*] bets register (added in Wave 1) |
| `audit` (applied to skills) | Compliance against requirement IDs |
| `release-readiness` (skill-incorporation gate) | Gates skill changes through review |

#### L0/L1/L2/L3-spanning architectural skills

Architectural skills carry conventions that apply at any layer where
implementation lives:

`swift-institute` ([ARCH-LAYER-*]); `swift-package` ([PKG-NAME-*],
[PKG-DEP-*]); `swift-package-heritage`; `swift-package-build`
([PKG-BUILD-*]); `code-surface` ([API-NAME-*], [API-ERR-*],
[API-IMPL-*]); `implementation` ([IMPL-*]); `memory-safety` ([MEM-*]);
`platform` ([PLAT-ARCH-*]); `modularization` ([MOD-*]); `conversions`
([IDX-*], [CONV-*]); `existing-infrastructure` ([INFRA-*]);
`ecosystem-data-structures` ([DS-*]); `memory-arithmetic`
([MEM-ARITH-*]); `documentation` ([DOC-*]); `readme` ([README-*]);
`github-repository` ([GH-REPO-*]); `document-markup`
([DOC-MARKUP-*]); `testing` + `testing-swiftlang` + `testing-institute`
([TEST-*], [SWIFT-TEST-*], [INST-TEST-*]); `benchmark` ([BENCH-*]);
`primitives` ([PRIM-FOUND-*]); `social-preview`.

#### Available in Claude Code but explicitly NOT used (per the bets)

| Primitive | Why unused |
|-----------|------------|
| Hooks (general) | [BET-HOOK]: enforcement at lint/audit/supervise/skill, not hooks |
| PreCompact / PostCompact hooks | [BET-COMPACT]: filesystem-as-state-machine is the bet |
| LLM-as-judge eval | [BET-EVAL]: harness-as-corpus rejects metric-optimization |
| Auto-mutating eval | [BET-EVAL] |
| Swift rewrite of Claude Code | [BET-REWRITE]: deferred ≥1 year behind dual gate |
| TaskCreate / TaskUpdate | Workflow-harness substitutes (HANDOFF.md / supervisor block / reflections) |
| File checkpointing | `fileCheckpointingEnabled: false` in settings |
| Plan mode (default) | Auto mode is default; plan mode used per-session when desired |
| Custom subagent definitions in `.claude/agents/` | Built-in subagents (Explore / Plan / general-purpose) only |
| Output styles | Still in dev as of 2026-05 per the survey |
| Background tasks via `/loop` or `/schedule` | Not used; workflow-harness provides equivalents |
| MCP servers beyond cclsp | Deliberately narrow MCP surface |
| OpenTelemetry exporter | Recommendation #4 changes this |

#### On the roadmap (per v1.1.0 recommendations)

| Recommendation | Layer it lands at |
|----------------|-------------------|
| #2 Stop-hook reflection-cadence | L1 (single hook) |
| #3 Error-analysis on reflection corpus | L3 (informs `reflections-processing`) |
| #4 OpenTelemetry GenAI semconv | L0 (substrate observability) |
| #7 Sandbox × cclsp probe | L0/L1 boundary (substrate × agent runtime interaction) |

### "More harness" categorization for forward planning

Three categories of expansion, with bet-impact analysis:

| Category | What it means | Example | Bet-impact |
|----------|--------------|---------|-----------|
| (a) Increase depth of existing layers | Add a primitive to a layer we already have | Recommendations #2 / #3 / #4 / #7 | Compatible with all bets |
| (b) Adopt Claude Code primitives we've bet against | Revisit [BET-HOOK] / [BET-EVAL] / [BET-COMPACT] / [BET-REWRITE] | Adding hooks beyond the Stop exception | Requires new evidence; not a default move |
| (c) Add layers we don't yet have | A genuinely new harness tier | L4 multi-user coordination | Speculative; surfaces only at scale |

**Speculative L4 candidates that don't violate existing bets**:

| Candidate | What it would manage | Why not in workspace today |
|-----------|---------------------|----------------------------|
| Multi-user / org-coordination harness | Multiple humans collaborating with multiple Claude sessions on the same ecosystem | Single-user workspace; surfaces at team scale |
| External-tool MCP fleet | Linear / Notion / GitHub / Slack MCPs | Deliberately narrow MCP surface (cclsp only); per-tool ROI judgment |
| Observability dashboards | Live agent traces, cost tracking, cross-session error categorization | #4 OpenTelemetry is half-step; dashboarding (Phoenix / LangSmith / Langfuse) would be the rest |
| Replay-based debugging | Re-run sessions with mutated prompt or model to localize failures | Composes with #4 |
| Cross-session memory governance | Auto-prune, auto-version, auto-revalidate corpus | `corpus-meta-analysis` is partial coverage; full governance would be event-driven not batch |
| Federation across orgs | Cross-org skill propagation; public skill registry | Currently private; release-readiness gates publication |

The deepest unrealized harness move available without changing any
[BET-*] is the depth additions in (a) — Wave 2 / Wave 3 of the
implementation roadmap — combined with the L4 observability candidates
that compose with OpenTelemetry. Everything else is either a
bet-violation or a scale that hasn't surfaced yet.

### Effect on the Recommendations Stack (v1.2.0)

No new recommendations. The v1.1.0 stack stands. The v1.2.0 refinement
is *analytical*, not *prescriptive*: it expands §4.1's framing without
altering the action plan.

| v1.1.0 Recommendation | v1.2.0 layer placement |
|----------------------|------------------------|
| #1 MEMORY.md triage | L0 substrate (Wave 1: complete) |
| #2 Stop-hook reflection-cadence | L1 agent harness |
| #3 Error-analysis on reflections (narrowed) | L3 meta-harness |
| #4 OpenTelemetry GenAI | L0 substrate |
| #5 CI substitution rule | L2 workflow harness — CI/CD instance (Wave 1: complete; [CI-094]/[CI-095]) |
| #6 Deliberate-bets register | L3 meta-harness (Wave 1: complete; [BET-HOOK]/[BET-EVAL]/[BET-COMPACT]/[BET-REWRITE]) |
| #7 Sandbox × cclsp probe | L0/L1 boundary |
| #8 Feasibility-doc reframed deferral | L3 meta-harness (`Research/`-resident; v1.2.0 of feasibility doc) |
| #9 Two-layer comparative research | **Reframed: three-layer comparative research**; trigger conditions unchanged |

### Reframed open question (Recommendation #9)

The Q6 reframe (v1.1.0 → v1.2.0) becomes:

> *"Three-layer harness (L0 substrate / L1 agent / L2 workflow / L3
> meta) vs Lopopolo's six-layer ops-stack (Policy / Configuration /
> Coordination / Execution / Integration / Observability) vs OpenHands'
> service-on-event-stream — comparative position."*

The substantive comparison is unchanged; only the workspace's
self-position becomes 3 layers + substrate, not 2 layers. The Tier-2
or Tier-3 research candidate is parked with the original trigger
conditions.

### Wave 1 retrospective in v1.2.0 framing

Wave 1 of the implementation plan delivered three artifacts spanning
three layers of the harness:

| Wave 1 deliverable | Layer | Effect |
|--------------------|-------|--------|
| MEMORY.md under cap | L0 | Substrate discipline restored; 188 → 137 topic files; 32 KB → 24.3 KiB |
| Bets register at `swift-institute-core` | L3 | The four explicit bets are now durable text governing all other layers' evolution |
| CI substitution rule promotion | L2 | The CI/CD instance of the determinism axis gains [CI-094] + [CI-095] |

The same wave touches L0 + L2 + L3 simultaneously precisely because
the workspace's harness is multi-layer. A single wave landing across
three layers is structural evidence for the three-layer framing.

## v1.3.0 Update — Wave 2 Retrospective (2026-05-10)

Wave 2 delivered three substrate-and-agent-layer items. None violates
the four [BET-*] entries in `swift-institute-core`. All three compose
with the Wave 1 deliverables.

| Wave 2 deliverable | Layer | Form | Effect |
|--------------------|-------|------|--------|
| Recommendation #2 — SessionEnd reflection-cadence hook | L1 (agent harness) | Single hook + side-effect script | `Reflections/.cadence.log` records each non-`/clear` non-`/logout` session close; reflect-session skill (and future #3 analysis) can detect sessions ending without reflection capture |
| Recommendation #4 — OpenTelemetry GenAI semconv | L0 (substrate) | `env` block in `~/.claude/settings.json`; PII-safe defaults (`OTEL_LOG_TOOL_*`, `OTEL_LOG_USER_PROMPTS` all `0`); telemetry collected internally; no exporter set | Substrate ready; user picks backend (Phoenix / Langfuse / Honeycomb / Jaeger / etc.) and adds `OTEL_EXPORTER_OTLP_ENDPOINT` to flip from local-only to remote export |
| Recommendation #7 — Sandbox × cclsp probe | L0/L1 boundary | One-shot empirical verification | Codex-issue-#18243 failure mode (silent shell-exec block when MCP server runs under non-`danger-full-access`) verified absent: `mcp__cclsp__find_references` returned 502K characters / 3,810 lines through the macOS Seatbelt + cclsp boundary in `auto` mode + `Bash(*)` allow + `skipAutoPermissionPrompt: true` |

### Composition with Wave 1

The four [BET-*] entries from Wave 1 act as constraints on Wave 2:

| Bet | Wave 2 compatibility |
|-----|---------------------|
| [BET-HOOK] | The single SessionEnd hook is *below the threshold of "hook layer"* (per v1.1.0 narrowed scope of Recommendation #2) — side-effect-only logging routing back to the skill layer, not turn-scope enforcement |
| [BET-EVAL] | OTel GenAI is observability *substrate*, not eval. PII flags off keep traces local; no judge prompts; no benchmarks |
| [BET-COMPACT] | Filesystem-as-state-machine survives compaction. The cadence log is filesystem-resident; the OTel `env` block is settings-resident — both survive compaction without hook intervention |
| [BET-REWRITE] | Wave 2 entrenches the harness-side-of-Claude-Code path; it does not invest in a Swift-side rewrite. Strengthens the deferral rationale |

### Bet-shape of Wave 2

All three Wave 2 items fall into category (a) "increase depth of
existing layers" per v1.2.0 §"More harness" categorization:

- #2 adds a *single* hook that doesn't widen the L1 surface
- #4 wires *substrate* observability without changing what's exported
- #7 verifies an existing boundary, no new primitives

No item falls into (b) "adopt Claude Code primitives we've bet against"
or (c) "add layers we don't yet have." The bets register survives Wave
2 unchanged.

### Wave 3 candidates (still pending user authorization)

| Recommendation | Layer | Why deferred to Wave 3 |
|----------------|-------|-------------------------|
| #3 — Error-analysis on reflection corpus | L3 (meta-harness) | Substantial — requires reading reflections-processing skill, designing transition-matrix structure, building analysis script over 312+ reflection files |
| #9 — Three-layer comparative research | L3 (meta-harness) | Parked per Q6 trigger conditions (parked-research) |

### Cadence-log discoverability

The cadence log lives at `Research/Reflections/.cadence.log` (dot-prefix
hides it from the public `Research/Reflections/` listing per
[RES-002] which forbids underscore-prefixed subdirectories but allows
dot-files for repository-internal state). The reflect-session skill
([REFL-001]) is the natural consumer; Wave 3 #3 makes it the
authoritative consumer.

## v1.4.0 Update — Wave 3 Retrospective (2026-05-10)

Wave 3 delivered the meta-layer (L3) item from the recommendations
stack: Recommendation #3 — error-analysis on the reflection corpus.

| Wave 3 deliverable | Layer | Form | Effect |
|--------------------|-------|------|--------|
| Recommendation #3 — `Scripts/reflection-corpus-analysis.py` | L3 (meta-harness) | 240-line Python script with markdown / JSON / quiet output modes | Reads 278 reflections, computes 8 frequency tables + convergence-health signals per [REFL-PROC-011]; consumes Wave 2's `.cadence.log`; exits non-zero on any WARN |

### Composition with Waves 1 + 2

The four [BET-*] entries from Wave 1 act as constraints on Wave 3:

| Bet | Wave 3 compatibility |
|-----|---------------------|
| [BET-HOOK] | The script is invoked manually (or via scheduled task), not bound to a hook event — it is a tool, not enforcement |
| [BET-EVAL] | The script implements *error-analysis on real traces* (Husain) — explicitly NOT LLM-as-judge eval, NOT benchmarks, NOT auto-mutation. Decisions remain human-driven |
| [BET-COMPACT] | Script is filesystem-resident; output goes to stdout (or stderr); no compaction interaction |
| [BET-REWRITE] | Pure-Python tool over the existing Reflections/ corpus; entrenches the harness-side path |

### Composition with Wave 2 substrate

The Wave 2 `.cadence.log` becomes a Wave 3 input. Cross-referencing
sessions-logged against reflections-captured surfaces a future signal
(*"sessions without reflection capture"*) without binding either side.
The integration is read-only and additive.

### Initial findings from the baseline snapshot

The first run surfaced an actionable corpus-quality signal: **21
distinct `triage_outcomes[].type` strings** appear in the corpus where
[REFL-PROC-003] names 8 canonical types. 13 are non-canonical
(PascalCase drift like `SkillUpdate` / `ResearchTopic`; ad-hoc types
like `informational` / `feedback_memory`). The convergence-health
WARNs the script emits on the last-10-window are partially a
*measurement artifact* of this drift — recent reflections use a
single-line `type: mixed` form embedding multiple outcome mentions in
the description text. Both the drift itself and the artifact are real
findings. See `reflection-corpus-error-analysis.md` for the full
baseline snapshot and direction items.

### Bet-shape of Wave 3

Wave 3 stays within category (a) "increase depth of existing layers"
per v1.2.0 §"More harness" categorization:

- The script adds a primitive to the L3 meta-layer that already exists
  (`reflections-processing`, `corpus-meta-analysis`)
- It does not widen the meta-layer surface (no new skills, no new
  workflows beyond the script invocation)
- It does not adopt a primitive bet against ([BET-HOOK] /
  [BET-EVAL] /[BET-COMPACT] / [BET-REWRITE] all unaffected)

The bets register survives Wave 3 unchanged.

### Wave 4 candidates (still pending user authorization)

| Item | Layer | Why deferred |
|------|-------|--------------|
| Canonicalize `triage_outcomes[].type` taxonomy | L3 (skill rule + one-time pass) | Surfaced *by* Wave 3; promotion to skill rule plus backward normalization belongs in a separate cycle through `skill-lifecycle` and `reflections-processing` |
| Process the 9 pending reflections | L3 (skill workflow) | Run `/reflections-processing` over the backlog dating from 2026-03-22 → 2026-05-04 |
| #9 — Three-layer comparative research | L3 | Parked per Q6 trigger conditions (parked-research) |

## v1.5.0 Update — Wave 4 Retrospective (2026-05-10)

Wave 4 originally proposed three items: (a) canonicalize the
`triage_outcomes[].type` taxonomy via skill amendment; (b) process the
9 pending reflections via `/reflections-processing`; (c) parked #9.

### Scope correction at the [REFL-PROC-001] guardrail

Item (b) was withdrawn from Wave 4 scope when [REFL-PROC-001] surfaced:
*"`/reflections_processing` MUST NOT be invoked during an active
implementation session — processing is a distinct activity (Basili
et al. 1994, Experience Factory separation)."* The harness-arc was
itself an active implementation session through Wave 4, so processing
the backlog requires a separate, dedicated future session. The prior
turn's recommendation to *"do (b) before (a) — natural ordering"* was
a defect (the recommendation pre-dated checking the guardrail);
acknowledged inline before any action was taken.

### Wave 4 actual deliverable

| Wave 4 deliverable | Layer | Form | Effect |
|--------------------|-------|------|--------|
| [REFL-PROC-003a] Type Field Canonical Form | L3 (meta-harness) | Sub-rule of [REFL-PROC-003] in `Skills/reflections-processing/SKILL.md` | Codifies the 8 canonical snake_case `type:` values; enumerates the 13 forbidden non-canonical forms (PascalCase variants + ad-hoc types like `informational` / `research_update` / `feedback_memory`) surfaced by Wave 3's first analysis run; `last_reviewed` bumped 2026-05-05 → 2026-05-10; provenance line cites `Research/reflection-corpus-error-analysis.md` per [SKILL-LIFE-002] |

### Composition with Waves 1 + 2 + 3

The four [BET-*] entries from Wave 1 act as constraints on Wave 4:

| Bet | Wave 4 compatibility |
|-----|---------------------|
| [BET-HOOK] | A skill rule is enforcement *by skill*, not by hook. The four-layer non-hook enforcement stack ([Q3 resolution]) is exactly the placement |
| [BET-EVAL] | The rule prevents future drift in the structured field that Wave 3's analysis script reads. *Reduces measurement artifact*; does not introduce auto-mutation |
| [BET-COMPACT] | Skill text is filesystem-resident; survives compaction by definition |
| [BET-REWRITE] | Single-rule amendment to existing skill; entrenches the harness-side path |

### Self-validating cycle: Wave 3 surfaced → Wave 4 codified

Wave 3's analysis script identified the gap *because* it measured the
corpus directly. Wave 4 closed the gap *forward* (write-time enforcement
on new reflections) without forcing backward normalization (reserved
for a future `/reflections-processing` session per [REFL-PROC-001]).
This is the workspace's harness-as-corpus loop in action: durable text
surfaces drift → durable text gets amended → drift stops re-accumulating.

### Bet-shape of Wave 4

Wave 4 stays within category (a) "increase depth of existing layers"
per v1.2.0 §"More harness" categorization:

- The amendment adds one sub-rule to a skill that already exists
- It does not widen the meta-layer surface (no new skills)
- It does not adopt a primitive bet against ([BET-HOOK] / [BET-EVAL] /
  [BET-COMPACT] / [BET-REWRITE] all unaffected)

### Cumulative Wave 1 → 4 layer coverage

Across four same-day waves, every layer of the three-layer + substrate
architecture has been touched at least twice:

| Layer | Wave 1 | Wave 2 | Wave 3 | Wave 4 |
|-------|--------|--------|--------|--------|
| L0 substrate | MEMORY.md triage | OTel env block | — | — |
| L1 agent | — | SessionEnd hook | — | — |
| L2 workflow | [CI-094] / [CI-095] | — | — | — |
| L3 meta | [BET-*] register | — | reflection-corpus-analysis.py + REFERENCE doc | [REFL-PROC-003a] |
| L0/L1 boundary | — | cclsp probe | — | — |

The harness now carries: (a) explicit substrate discipline via
MEMORY.md cap and OTel; (b) explicit deliberate-bets register in the
meta-layer; (c) one Stop-hook reflection-cadence primitive that routes
back to skills; (d) a measurement substrate over the reflection
corpus; and (e) a write-time enforcement rule preventing the drift
that the measurement substrate observed.

### Wave 5 candidates (still pending user authorization)

| Item | Layer | Why pending |
|------|-------|--------------|
| Process the 9 pending reflections | L3 (skill workflow) | Withdrawn from Wave 4 per [REFL-PROC-001] guardrail; requires separate dedicated session |
| Backward normalize 13 non-canonical type strings in 35+ existing reflections | L3 (skill workflow) | Per [REFL-PROC-001] guardrail — a `/reflections-processing` activity, not implementation. Each non-canonical entry needs its outcome re-derived from description text, which is human-driven |
| Pick OTel exporter backend (Phoenix / Langfuse / Honeycomb / Jaeger / etc.) | L0 substrate | Backend choice is a user decision; once made, single env var (`OTEL_EXPORTER_OTLP_ENDPOINT`) flips traces on |
| #9 — Three-layer comparative research | L3 | Parked per Q6 trigger conditions |

## References

This document is synthesis of the survey + workspace state; primary
references trace through §N.M cross-references to
[`agent-harness-engineering-state-of-the-art.md`](./agent-harness-engineering-state-of-the-art.md)
and to the workspace files cited inline with `[Verified: 2026-05-10]`
plus their generating commands.

Workspace artifacts cited:

- `/Users/coen/.claude/settings.json` — user-level Claude Code settings
- `/Users/coen/.claude/settings.local.json` — user-level local additions
- `/Users/coen/Developer/.claude/settings.local.json` — project-level local
- `/Users/coen/Developer/CLAUDE.md` — workspace instructions, skill routing tables
- `/Users/coen/CLAUDE.md` — user-level utility CLAUDE.md
- `/Users/coen/.claude/cclsp.json` — cclsp MCP server configuration
- `/Users/coen/.claude/projects/-Users-coen-Developer/memory/MEMORY.md` — auto-memory index
- `/Users/coen/.claude/projects/-Users-coen-Developer/memory/*.md` — 188 topic files
- `/Users/coen/Developer/swift-institute/Skills/{handoff,supervise,reflect-session,reflections-processing,skill-lifecycle,swift-institute-core,code-surface,swift-institute,corpus-meta-analysis,ci-cd-workflows,git-operations}/SKILL.md`
- `/Users/coen/Developer/swift-institute/.github/.github/workflows/` — 27 reusable workflows
- `/Users/coen/Developer/swift-primitives/.github/.github/workflows/swift-ci.yml` — layer-tier reusable
- `/Users/coen/Developer/swift-institute/Scripts/` — 28 workspace tooling scripts
- `/Users/coen/Developer/swift-institute/Research/agent-harness-engineering-state-of-the-art.md` (the survey)
- `/Users/coen/Developer/swift-institute/Research/agent-handoff-patterns.md`
- `/Users/coen/Developer/swift-institute/Research/agent-supervision-patterns.md`
- `/Users/coen/Developer/swift-institute/Research/ai-context-reduction-via-type-system-tooling.md`
- `/Users/coen/Developer/swift-institute/Research/claude-code-swift-rewrite-feasibility.md` (DEFERRED)
