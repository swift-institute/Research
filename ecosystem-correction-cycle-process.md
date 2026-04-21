# Ecosystem Correction-Cycle Process

Reusable workflow for auditing and correcting a type family across the
Swift Institute ecosystem. Distilled from the path-primitives correction
cycle (2026-04-18, 20 commits across 4 repos).

## When to use

Invoke this process when a type family has cross-layer concerns — same
identifier meaning different things at different layers, suboptimal
performance from layer-cross friction, API-NAME violations, or
architectural pressure without a clear resolution.

Scope examples: paths, strings, errors, time types, descriptors,
serialization types. Not for: single-package refactors, bug fixes
bounded to one layer, or cosmetic renames.

---

## Phases

### Phase 0 — Survey (5 min, direct)

Quick tour of the ecosystem to scope the analysis. Grep / ls across:
- L1 primitives (`/Users/coen/Developer/swift-primitives/swift-*-primitives/`)
- L2 standards (`/Users/coen/Developer/swift-iso/`, `swift-microsoft/`)
- L3 foundations (`/Users/coen/Developer/swift-foundations/`)

Output: a short list of candidate packages the model agent should inspect.
Done directly by the orchestrating agent, not delegated.

### Phase 1 — Model (30 min, one agent)

Launch **one** general-purpose agent to produce the reference model at
`/Users/coen/Developer/swift-institute/Research/{domain}-type-ecosystem-model.md`.

**Template**: read the path model at `path-type-ecosystem-model.md` —
the string / time / error models mirror its structure.

**Required output sections**:
1. Overview + ASCII layer diagram
2. Type reference table (full qualified name, layer, storage, NUL-term?,
   Copyable?, Escapable?, encoding, API surface, platform variation,
   error model)
3. Conversion graph (edge list: from type, to type, mechanism, alloc
   profile, owning layer)
4. Character / byte representation matrix (if domain has platform-
   varying bytes like Path.Char UInt8/UInt16)
5. Encoding / invariant matrix (if domain has validation rules)
6. Kernel / syscall bridging (if domain crosses into kernel types)
7. Divergence flags (D1–Dn) — known or suspected cross-layer
   inconsistencies
8. Open questions (things the agent could not resolve)

**Length target**: 400–900 lines. Terse but complete.

**Ground rules for the model agent**:
- Read via Read/Grep/Glob only; no `swift build` / `swift test`
- No source modifications; only write the model file
- Verify facts by reading source; cite absolute paths + line numbers
- Flag absences as findings (e.g., "no Windows conformance file exists")

### Phase 2 — Three perspective analyses (parallel, 3 agents)

Launch three agents **in parallel**, one per skill:

| Agent | Skill loaded | Focus |
|---|---|---|
| Implementation perspective | `/implementation` | Expression-first patterns, ownership flow, allocation profile, compile-time enforcement, divergence risks, concrete implementation sketch |
| Platform perspective | `/platform` | Separator / encoding / char-type parameterization, `#if os()` boundaries, PLAT-ARCH compliance, cross-platform coverage |
| Modularization perspective | `/modularization` | Dependency fan-out, target decomposition, conformance visibility, consumer import precision, SEM-DEP essential vs incidental |

Each agent:
- Reads the model in full
- Reads the cited source files
- Produces a structured markdown report (400–800 lines) with per-question position, rationale with cited requirement IDs, tradeoff, confidence
- Does NOT write files (report returned inline)
- Flags any Model corrections found

The three reports arrive independently; the orchestrator synthesizes.

### Phase 3 — Orchestrator synthesis

Combine the three perspective reports into a bullet-form action plan:
- Points of agreement (the consensus)
- Points of disagreement (surface for user)
- Concrete wave-numbered PR plan (dependencies explicit)
- Recommended starting point

This is done directly, not delegated. Output goes to user inline, not
a file.

### Phase 4 — Professor audit (optional, 1 agent)

When the user wants first-principles review beyond the skill-based
perspectives, launch a fresh general-purpose agent in the *professor*
role:
- Instructed to find 5–6 first-principles findings ordered by
  compounding cost
- May challenge the perspectives' conclusions
- Produces a correction-cycle plan (Wave 1..N)

The professor does not load skills — the framing is academic, not
ecosystem-internal.

### Phase 5 — Implementation architect response (optional, 1 agent)

After the professor, launch the *implementation architect* in the
orchestrator role (or directly produce the response in the main
conversation). The architect:
- Accepts each finding, refines it, or rejects with alternative
- Resequences the waves if write-then-delete patterns emerge
- Adds safeguard waves (e.g., Wave 0 cross-layer equivalence tests)
- Surfaces any disagreement with the professor explicitly

This produces the authoritative action plan.

### Phase 6 — Workgroup for open decisions (optional, 4 agents)

When Phase 5 identifies 2–3 decisions that need input from multiple
angles, convene a workgroup. Four parallel agents with distinct
priorities:

| Role | Priorities |
|---|---|
| API stewardship | API-NAME rules, surface minimalism, symmetry, backward compat cost |
| Ecosystem integration | Consumer call sites, migration cost, user expectation, actual (not theoretical) usage |
| Specifications fidelity | POSIX / Windows / Apple Foundation / Rust / Go / Python precedent; cite WebSearch |
| Release engineering | Semver, migration paths, deprecation windows, release state |

Each agent:
- Reads the model + any relevant perspective reports
- Researches actual consumer code / external specs / release state
- Produces structured answer per decision: position, rationale (with
  cited grep counts / external spec URLs / release tags), tradeoff,
  confidence
- Takes a position — "it depends" is rejected

Orchestrator synthesizes into a final resolution per decision, noting
minority opinions.

### Phase 7 — Waves (implementation)

PRs landed in dependency order. Naming convention: `Wave {N} PR {letter}:
{subject}`. Wave 0 is always safeguard tests; subsequent waves depend
on Wave 0.

**Canonical wave structure** (adapt to domain):

| Wave | Content |
|---|---|
| **0** | Cross-layer equivalence tests (catches all subsequent drift) |
| **1** | Add L1 primitive / shared algorithm; L2 conformers delegate |
| **2** | Protocol restructure (if needed); source-compat bridge removed same wave |
| **3** | L3 adopts new protocol / deletes duplicated code |
| **4** | API-surface alignment (rename, convention fix); breaking if needed |
| **5** | Extend byte-scan / algorithmic improvement across remaining methods |

Each PR:
- Single repo (or co-located cross-repo if trivial)
- Commit message includes PR identifier, summary, rationale, test count
- Build + test green before commit
- No backwards-compat shims unless user explicitly requests them
- Research notes for deferred items (not in commit)

### Phase 8 — Deferred items

Items the workgroup parked: record as research notes in
`swift-institute/Research/{domain}-{topic}.md`. Each note:
- Status (OPEN / BLOCKED / DEFERRED / RESOLVED)
- Why it exists
- Proposed design (if resolvable later)
- Dependencies (what has to land first)
- Cross-references

---

## Cross-cutting rules

### Ask discipline

Read feedback memory and `~/CLAUDE.md` before running destructive or
expensive commands. Ask before `swift build` / `swift test` if the user
has asked for this.

### No silent breaking changes

If a change shifts runtime behavior for identical source ("compiles same,
acts different"), surface it before committing. Rename the symbol to
force caller attention.

### Pre-1.0 discipline

If no repo tags exist (`git tag --list` empty), breaking changes are
cheap. Delete rather than deprecate. Skip compat shims.

### Commit cadence

One PR = one commit. Each PR builds green. Each PR tests green
(run tests locally per user directive). Chain PRs by numbered waves
so history reads as a narrative.

### Cross-repo commits

Never one commit across repos. Commit L1 first, then L2, then L3. If
an L2 conformer needs a new L1 symbol, land L1 with the symbol, then
L2 with the conformance in a second commit.

### Safeguard tests before breakage

Wave 0 exists for a reason. Lock cross-layer equivalence before ANY
later wave. Property-based fixtures for paths with random separator
patterns; random validated byte fixtures for strings; etc.

### Research notes for rejected alternatives

If the user rejects an approach ("don't use Result, use throws(E)"),
that becomes a feedback memory or a research note. Prevents the next
session retreading the same ground.

---

## Artifact locations

```
swift-institute/Research/
├── {domain}-type-ecosystem-model.md       Phase 1 output
├── {domain}-{specific-design}.md          Phase 8 deferred designs
└── ecosystem-correction-cycle-process.md  This document

swift-institute/HANDOFF-{domain}-correction-cycle.md    per-domain handoff
swift-institute/HANDOFF.md                              rolling work (stale path Phase 4b still there)
```

---

## Agent prompt skeletons

### Model agent prompt skeleton

```
Produce a comprehensive top-to-bottom model of every {domain}-related
type in the Swift Institute ecosystem. This will inform a correction-
cycle analysis — professor audit, implementation architect review,
workgroup decisions — downstream.

## Context

[5-layer architecture location paths]

Prior path-type model at Research/path-type-ecosystem-model.md is the
template.

## Starting inventory

[list of packages surveyed in Phase 0]
Also discover: [named omissions]

## Tasks

1. Inventory every {domain}-related type
2. Map the conversion graph
3. {domain-specific matrices: char-type, encoding, kernel bridge}
4. Divergence flags
5. Open questions

## Output

Write to swift-institute/Research/{domain}-type-ecosystem-model.md.
Length 400–900 lines, mirror the path model structure.

## Ground rules

- Read only; no swift build/test
- No source modifications; only the model file
- Cite absolute paths + line numbers
- Flag absences as findings

## Report back

Under 200 words: (a) file path, (b) types inventoried, (c) highest-
stakes finding, (d) missing packages you could not locate.
```

### Perspective agent prompt skeleton

```
You are one of three parallel analysts on the {domain} correction
cycle.

## Required reading

1. Your skill: /Users/coen/Developer/swift-institute/Skills/{skill}/SKILL.md
2. Model: Research/{domain}-type-ecosystem-model.md
3. Relevant source files (list absolute paths)

## Your role: {implementation | platform | modularization}

[role priorities]

## Produce

Structured markdown report, 400–800 lines, returned inline (no file).

### TL;DR (2 sentences)
### Section per question
- Position (take one — no "it depends")
- Rationale (cite requirement IDs literally)
- Tradeoff you accept
- Confidence: high/medium/low

### Cross-cutting
### Model corrections (if any discrepancy found)

## Constraints

- Don't hedge
- No file writes
- No swift build/test
- Cite [ID] tags literally
```

### Workgroup member prompt skeleton

```
You are one of four members on the {domain} workgroup, convened to
resolve {N} open architectural decisions.

## Required reading

[model + cited sources + any research docs]

## Your role: {API stewardship | Ecosystem integration | Specs fidelity | Release engineering}

[role priorities + worry list]

## The decisions (one heading each)

{D1, D2, ..., with alternatives framed}

## Produce

Markdown report, 400–700 lines, returned inline.

### TL;DR (2 sentences covering all decisions)
### Section per decision
- Position
- Rationale (cite {grep counts | external specs | requirement IDs}
  as appropriate to your role)
- Tradeoff
- Confidence

### Cross-cutting (decision interactions from your POV)

## Constraints

- Take positions
- No file writes
- [role-specific ground rules]
```

---

## Reusable in other domains

This process applies to any ecosystem type family. Invoke it for:

- Strings (pending — HANDOFF-string-correction-cycle.md)
- Errors (future — typed throws conventions, Error namespace patterns)
- Time types (future — Clock.Instant, Duration, typed vs raw UInt64)
- Descriptors (future — Kernel.Descriptor bridging across layers)
- Serialization (future — Binary, JSON, Plist interop)

Each domain inherits the phase structure. Only the model content,
perspective questions, and workgroup decisions differ.

---

## Cross-references

- `/handoff` skill — file format for spawning correction cycles
- `/supervise` skill — ongoing oversight during phase execution
- `/audit` skill — systematic compliance check (narrower than correction)
- `/research-process` skill — the Research/ directory conventions
- `/implementation`, `/platform`, `/modularization` skills — perspective lenses
- `path-type-ecosystem-model.md` — worked example of Phase 1 output
- `path-components-lazy-bidirectional-collection.md` — worked example of Phase 8 deferred design note
