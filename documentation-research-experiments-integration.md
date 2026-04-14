# Documentation–Research–Experiments Integration

<!--
---
version: 1.1.0
last_updated: 2026-03-15
status: SUPERSEDED
superseded_by: documentation skill [DOC-028], [DOC-029]
---
-->

## Context

Three skills govern documentation artifacts:
- `/documentation` — inline DocC comments + .docc catalogue ([DOC-*])
- `/research-process` — Research/ documents ([RES-*])
- `/experiment-process` — Experiments/ packages ([EXP-*])

These three are currently disconnected. Research/ and Experiments/ live as siblings to Documentation.docc/ with no DocC integration. The pattern of hosting companion documents physically inside .docc/ demonstrates that explanatory material CAN be DocC-navigable.

## Question

How should Research/ and Experiments/ integrate with .docc to create a unified, navigable documentation experience — while preserving existing conventions?

## Constraints

| Artifact | Format | Can live inside .docc? | Current location convention |
|----------|--------|:---:|---|
| Research | Markdown (.md) | Yes | [RES-002] `{package}/Research/` |
| Experiments | Swift packages (Package.swift + Sources/) | No | [EXP-002] `{package}/Experiments/` |
| .docc articles | Markdown (.md) | Yes (native) | [DOC-020] `Sources/{Module}/{Module}.docc/` |

**Hard constraint**: Experiments are Swift packages. They cannot physically reside inside .docc. Only references to them can.

**Naming**: Research uses kebab-case filenames ([RES-003b]). Kebab-case subdirectories are already acceptable inside .docc.

## Analysis

### Option 1: Physical Move — Research/ INTO .docc/

Research/ moves from package root into `.docc/Research/`. Experiments stays at package root.

```
Sources/{Module}/{Module}.docc/
├── {Module}.md
├── {Article}.md
├── Research/
│   ├── _index.md
│   └── heap-storage-variants.md
└── ...

{package}/
└── Experiments/        (stays here)
    ├── _index.md
    └── heap-drain-exclusivity/
```

**Impact on /research-process**: [RES-002] location convention changes. Package-specific research moves from `{package}/Research/` to `{package}/Sources/{Module}/{Module}.docc/Research/`.

**Pros**: Full DocC integration. `<doc:Research/heap-storage-variants>` links work natively. Root page `## Topics` can include `### Research` section.

**Cons**: Breaks existing git history for moved files. Monorepo challenge — which module's .docc gets the research when multiple modules exist? Research doesn't naturally "belong to" a module; it belongs to the package.

---

### Option 2: Symlink — Research/ stays, .docc symlinks to it

Research/ stays at package root. A symlink inside .docc points to it.

```
{package}/
├── Research/                   (physical location)
│   ├── _index.md
│   └── heap-storage-variants.md
├── Sources/{Module}/{Module}.docc/
│   ├── {Module}.md
│   └── Research -> ../../../Research/   (symlink)
└── Experiments/                (physical location)
    └── ...
```

**Impact on /research-process**: No change to [RES-002]. Research stays where it is.

**Pros**: Zero disruption to existing conventions. DocC discovers content through symlink. Research is navigable in rendered docs AND accessible at the expected filesystem location.

**Cons**: Symlinks in git require care (but already used for skills). Monorepo: multiple modules could symlink to the same Research/. DocC compiler must follow symlinks (standard filesystem behavior, should work).

---

### Option 3: Bridge Index — .docc index pages reference external content

Research/ and Experiments/ stay at package root. Inside .docc, dedicated index articles link to them via relative markdown links.

```
Sources/{Module}/{Module}.docc/
├── {Module}.md
├── Research.md           ← bridge index with markdown links
└── Experiments.md        ← bridge index with markdown links
```

`Research.md` content:
```markdown
# Research

| Document | Status | Link |
|----------|--------|------|
| Heap Storage Variants | DECISION | [View](../../../Research/heap-storage-variants.md) |
```

**Impact on /research-process**: No change.

**Pros**: Simplest implementation. No symlinks, no moves. Research/Experiments content is reachable from DocC navigation.

**Cons**: Partial integration only. Research docs don't render in DocC — the link takes you out to the raw .md file. No `<doc:>` syntax for individual research documents. The bridge index must be manually maintained.

---

### Option 4: Hybrid — Research inside .docc, Experiments via bridge

Research/ moves into .docc/ (full integration). Experiments/ stays at package root with a bridge index in .docc.

```
Sources/{Module}/{Module}.docc/
├── {Module}.md
├── Research/
│   ├── _index.md
│   └── heap-storage-variants.md
└── Experiments.md           ← bridge index for experiments
```

**Impact**: [RES-002] changes for research. [EXP-002] unchanged for experiments.

**Pros**: Best possible integration for research (DocC-native). Pragmatic approach for experiments (can't be DocC-native, so bridge is appropriate). Clean separation based on what's physically possible.

**Cons**: Research location changes. Same monorepo challenge as Option 1.

---

### Comparison

| Criterion | 1: Move | 2: Symlink | 3: Bridge | 4: Hybrid |
|-----------|---------|-----------|-----------|-----------|
| Research in DocC navigation | Full | Full | Index only | Full |
| Experiment references in DocC | Bridge | Bridge | Bridge | Bridge |
| Disruption to /research-process | High | None | None | High |
| Disruption to /experiment-process | None | None | None | None |
| `<doc:>` links to research | Yes | Yes | No | Yes |
| Git history preserved | No | Yes | Yes | No |
| Monorepo safety | Poor | Good | Good | Poor |
| Maintenance burden | Low | Low | High (manual) | Low |

## Monorepo Consideration

swift-primitives is a monorepo with 61+ packages. Research/ at the monorepo root contains cross-package research. Individual packages also have their own Research/ directories. Which module's .docc "owns" the root Research/?

**Resolution**: The monorepo has a root-level `Documentation.docc/` (e.g., `swift-primitives/Documentation.docc/`). Root-level Research/ symlinks (or moves) into this root-level .docc. Package-specific Research/ symlinks (or moves) into that package's module .docc.

| Scope | Research Location | .docc Location |
|-------|-------------------|----------------|
| Package-specific | `{package}/Research/` | `Sources/{Module}/{Module}.docc/Research/` |
| Monorepo-wide | `{monorepo}/Research/` | `{monorepo}/Documentation.docc/Research/` |
| Ecosystem-wide | `swift-institute/Research/` | `swift-institute/Documentation.docc/Research/` |

## Experiment Bridge Pattern

Since experiments cannot live in .docc, the bridge pattern applies to ALL options:

**.docc article → Experiment reference:**
```markdown
## Experiments

- [heap-drain-exclusivity](../../Experiments/heap-drain-exclusivity/) — Verifies exclusivity enforcement in heap drain operations. Status: CONFIRMED.
```

**.docc Experiments.md index page:**
```markdown
# Experiments

Empirical verification of design decisions. Each experiment is a standalone Swift package.

| Experiment | Purpose | Status |
|-----------|---------|--------|
| [heap-drain-exclusivity](../../Experiments/heap-drain-exclusivity/) | Exclusivity enforcement | CONFIRMED |
```

**Individual .docc article pages** MAY include a `## Experiments` section referencing relevant experiments.

## .docc Article Section Expansion

Regardless of which option is chosen, .docc article pages gain two new optional sections:

| Section | Content | Link type |
|---------|---------|-----------|
| `## Research` | Links to relevant research documents | `<doc:>` (Options 1/2/4) or markdown (Option 3) |
| `## Experiments` | Links to relevant experiments | Markdown links (always — experiments can't be in .docc) |

These follow the same pattern as explanatory-material sections (e.g., `## Rationale`) — explanatory depth exclusive to .docc, not in inline docs.

## Inline Documentation Rule

**Inline `///` comments MUST NOT reference Research/ or Experiments/ documents.** Inline docs are the self-sufficient developer reference for spec text, examples, and cross-references. Research and experiment references are depth content that belongs exclusively in .docc articles.

## Decision

**Content references** — Research/ and Experiments/ stay at package root. The .docc articles reference them via relative markdown links in their content. No symlinks, no moves.

Rationale:
- Zero disruption to existing /research-process and /experiment-process conventions
- Research/ stays at package root per [RES-002]
- Experiments/ stays at package root per [EXP-002]
- .docc articles gain `## Research` and `## Experiments` sections with relative markdown links
- Inline `///` docs MUST NOT reference Research/ or Experiments/
- Simple, no structural changes, no symlink management

**Skill updates applied:**

| Skill | Change |
|-------|--------|
| `/documentation` | Added [DOC-028] Research references in .docc articles, [DOC-029] Experiment references in .docc articles. Expanded [DOC-023] with `## Research` and `## Experiments` sections. Updated [DOC-010] to exclude research/experiment refs from inline docs. Updated content layering table in [DOC-027]. |
| `/research-process` | No change needed — [RES-002] location convention unchanged. |
| `/experiment-process` | No change needed — [EXP-002] location convention unchanged. |

## References

- `swift-institute/Research/documentation-skill-design.md` — Parent research
- `Skills/research-process/SKILL.md` — [RES-002]
- `Skills/experiment-process/SKILL.md` — [EXP-002]
