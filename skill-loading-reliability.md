# Skill Loading Reliability

<!--
---
version: 1.1.0
last_updated: 2026-03-10
status: SUPERSEDED
tier: 2
---
-->

## Context

**Trigger**: After completing the skill-first documentation refactor, we discovered that skills are not reliably applied during implementation. When a user starts Claude from `/Users/coen/Developer` and asks to create a new package in swift-primitives, there is no guarantee that naming, errors, or primitives skills will be invoked.

**Constraints**:
- Skills require explicit `Skill()` tool invocation to load full content
- Only skill descriptions (~30-50 tokens each) are loaded at session start
- CLAUDE.md files are eagerly loaded with full content
- No repos (swift-primitives, swift-standards, swift-foundations) have a CLAUDE.md
- The per-package `Skills/SKILL.md` files in swift-primitives are not wired into `.claude/skills/` discovery

**Scope**: Ecosystem-wide — affects all repos and all implementation tasks.

**Precedent Risk**: Medium — establishes the pattern for how skills integrate with CLAUDE.md across all repos.

---

## Question

How should skills be reliably loaded when working in Swift Institute repositories?

---

## Prior Art Survey

### Claude Code Discovery Mechanics

Claude Code has two independent content systems:

| System | Loading | Context Cost | Invocation |
|--------|---------|-------------|------------|
| CLAUDE.md | Eager — full content at session start | Every token, every session | Automatic |
| Skills | Two-stage — description only at start, full on invoke | Minimal until invoked | Explicit (Skill tool) or model-decided |

**Key discovery rules:**

1. **CLAUDE.md**: Walks UP from cwd to `/`. All files on the path are loaded eagerly. Subdirectory CLAUDE.md files load lazily when files in that subtree are accessed.
2. **Skills**: Discovered at project-level (`cwd/.claude/skills/`) and home-level (`~/.claude/skills/`). Subdirectory skills are discovered lazily.
3. **Rules**: `.claude/rules/*.md` files are auto-loaded eagerly at session start, similar to CLAUDE.md.

**Critical finding**: Launching from `/Users/coen/Developer` loads `/Users/coen/Developer/.claude/skills/` (16 skills). But launching from `/Users/coen/Developer/swift-primitives` only loads `swift-primitives/.claude/skills/` (10 skills) plus `~/.claude/skills/` (11 skills) — **not** the Developer-level skills.

### Current State

| Repo | CLAUDE.md | `.claude/skills/` | Skill discovery |
|------|-----------|-------------------|-----------------|
| `/Users/coen/Developer/` | Yes (routing table) | Yes (16 symlinks) | Only when cwd = Developer |
| `swift-primitives/` | No | Yes (10 symlinks) | Only when cwd = swift-primitives |
| `swift-standards/` | No | No | None |
| `swift-foundations/` | No | No | None |

---

## Analysis

### Option A: Per-Repo CLAUDE.md with Skill Invocation Directives

Add a CLAUDE.md to each repo with mandatory skill invocation directives:

```markdown
# Swift Primitives

Before writing ANY code, you MUST invoke these skills:
1. `primitives` — tier architecture, Foundation-independence
2. `naming` — Nest.Name pattern, no compound identifiers
3. `errors` — typed throws
4. `platform` — Package.swift, Swift 6 settings
```

**Advantages:**
- CLAUDE.md loads automatically (eager for cwd, lazy for subtree)
- Explicit directive — Claude sees "MUST invoke" in context
- Works regardless of launch directory
- Simple to implement

**Disadvantages:**
- Relies on Claude following the directive (soft enforcement)
- Skill invocation still requires explicit tool calls
- Directive text consumes context every session

### Option B: `.claude/rules/` Files

Use `.claude/rules/*.md` files in each repo. Rules are auto-loaded eagerly and have higher precedence than CLAUDE.md.

```
swift-primitives/.claude/rules/
  01-skills.md    → "MUST invoke primitives, naming, errors, platform skills"
```

**Advantages:**
- Rules are eagerly loaded, higher precedence than CLAUDE.md
- Can be numbered for ordering (01-, 02-)
- Separate from CLAUDE.md project memory

**Disadvantages:**
- Same soft enforcement as Option A
- Rules directory not yet used in the ecosystem
- Same context cost

### Option C: Inline Critical Rules in CLAUDE.md, Skills for Detail

Put the top critical rules directly in per-repo CLAUDE.md (always in context), with directives to invoke skills for full detail.

```markdown
## Non-Negotiable Rules
- All types MUST use Nest.Name pattern (never compound names)
- All throws MUST be typed throws
- No Foundation imports
- One type per file

## Before Writing Code
Invoke skills: primitives, naming, errors, platform
```

**Advantages:**
- Critical rules are always in context — no tool call needed
- Belt-and-suspenders: rules enforced even if skills not invoked
- Skills provide full detail when invoked

**Disadvantages:**
- Duplicates content between CLAUDE.md and skills
- CLAUDE.md grows with rules
- Maintenance burden — two places to update

### Option D: Per-Repo CLAUDE.md That Imports Skills via `@`

CLAUDE.md supports `@path/to/file` imports (up to 5 levels deep). Import skill content directly:

```markdown
@../swift-institute/Skills/naming/SKILL.md
@../swift-institute/Skills/errors/SKILL.md
@../swift-institute/Skills/primitives/SKILL.md
```

**Advantages:**
- Full skill content loaded eagerly — no invocation needed
- Single source of truth (skills are the canonical files)
- No duplication — CLAUDE.md imports, doesn't copy

**Disadvantages:**
- Loads all imported skill content every session (context cost)
- `@` imports may not resolve symlinks reliably across repos
- May hit the 5-hop import depth limit with nested imports
- Untested with the current skill YAML frontmatter format

---

## Comparison

| Criterion | A: Directive | B: Rules | C: Inline + Directive | D: Import |
|-----------|-------------|----------|----------------------|-----------|
| Reliability | Medium | Medium | High | High |
| Context cost | Low (~50 tokens) | Low (~50 tokens) | Medium (~200 tokens) | High (~2000+ tokens) |
| Maintenance | Low | Low | Medium (dual-source) | Low (single source) |
| Implementation effort | Low | Low | Medium | Low |
| Works across launch dirs | Yes (lazy load) | Yes (if in repo) | Yes (lazy load) | Yes (lazy load) |
| No duplication | Yes | Yes | No | Yes |
| No tool call needed | No | No | Partial (critical rules only) | Yes |

---

## Outcome

**Status**: SUPERSEDED (2026-03-10)
**Superseded by**: Per-repo CLAUDE.md convention (now standard practice)
This research was absorbed into the per-repo CLAUDE.md convention. It remains as historical rationale.

**Previous Status**: DECISION

**Choice**: Option A (Per-Repo CLAUDE.md with Skill Invocation Directives)

**Rationale**:

1. **Sufficient reliability**: The Developer/CLAUDE.md already contains critical rules inline (Nest.Name, typed throws, no Foundation, one-type-per-file). These are enforced without skill invocation. The per-repo CLAUDE.md adds a mandatory directive to invoke skills, which provides the full detail.

2. **Context efficiency**: Loading 4+ full skills (~2000 tokens each) every session via imports (Option D) is wasteful. Most sessions don't need all skills. The directive approach loads ~50 tokens of directive, and skills load only when relevant.

3. **No duplication**: Unlike Option C, this doesn't duplicate content. The Developer/CLAUDE.md already has the critical rules; per-repo CLAUDE.md just adds the invoke directive.

4. **Simplicity**: One file per repo, a few lines each. No new infrastructure (rules directories), no import chain risks.

5. **Lazy loading works**: Even when launching from `/Users/coen/Developer`, a CLAUDE.md in `swift-primitives/` will load when Claude first reads files in that directory — which happens before any code is written.

**Implementation**:

Create CLAUDE.md in each repo root with:
- Brief repo description
- Mandatory skill invocation directive listing the relevant skills
- `swift build` / `swift test` reminders specific to that repo

**Follow-up considerations**:
- Monitor whether the directive is reliably followed
- If not, escalate to Option C (inline critical rules) or Option D (imports)
- The `@` import mechanism (Option D) is a strong fallback if directives prove unreliable

---

## References

- Claude Code documentation: [Memory](https://code.claude.com/docs/en/memory), [Skills](https://code.claude.com/docs/en/skills)
- Swift Institute skill-based-documentation-architecture.md (predecessor research)
